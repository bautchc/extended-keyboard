# frozen_string_literal: true

# MIT No Attribution
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Generates the Mugwriter body of an AutoHotkey script named in ARGV[0] or the first .ahk file in the current directory
# if no ARGV[0] is passed.

require 'json' # license: BSD-2-Clause

SHIFT_MAP = {
  '~' => '+`',
  '!' => '+1',
  '@' => '+2',
  '#' => '+3',
  '$' => '+4',
  '%' => '+5',
  '^' => '+6',
  '&' => '+7',
  '*' => '+8',
  '(' => '+9',
  ')' => '+0',
  '_' => '+-',
  '+' => '+=',
  'Q' => '+q',
  'W' => '+w',
  'E' => '+e',
  'R' => '+r',
  'T' => '+t',
  'Y' => '+y',
  'U' => '+u',
  'I' => '+i',
  'O' => '+o',
  'P' => '+p',
  '{' => '+[',
  '}' => '+]',
  '|' => '+\\',
  'A' => '+a',
  'S' => '+s',
  'D' => '+d',
  'F' => '+f',
  'G' => '+g',
  'H' => '+h',
  'J' => '+j',
  'K' => '+k',
  'L' => '+l',
  ':' => '+;',
  '"' => '+\'',
  'Z' => '+z',
  'X' => '+x',
  'C' => '+c',
  'V' => '+v',
  'B' => '+b',
  'N' => '+n',
  'M' => '+m',
  '<' => '+,',
  '>' => '+.',
  '?' => '+/'
}.tap { |shift_map| shift_map.default_proc = Proc.new { |hash, key| hash[key] = key } }

SPECIAL_CHARACTERS = {' ' => 'Space'}.tap do |special_characters|
  special_characters.default_proc = Proc.new { |hash, key| hash[key] = key }
end

# (String, Hash[String, String|Hash[String, String]], Symbol) -> [Hash[String, String|Hash[String, String]], Symbol]
def parse_header(line, data, section)
  if line.start_with?(/ *;;;/)
    section = :body
  else
    data['_header'] = data['_header'] ? "#{data['_header']}\n#{line}" : line
  end
  [data, section]
end

# (
#   String,
#   Hash[String, String|Hash[String, String]],
#   Symbol,
#   String
# ) -> [Hash[String, String|Hash[String, String]], Symbol, String]
def parse_body(line, data, section, block)
  if line.start_with?(/[^; ]/)
    section = :prepend
  else
    if line.start_with?(/ *;;;/)
      block = line.match(/\A *;;; ?(.*[^ ]) *\z/)[1]
      data[block] = {}
    elsif line.start_with?(/ *;/)
      match = line.match(/\A *; (.) (.*[^ ]) *\z/)
      data[block][match[1]] = match[2]
    end
  end
  [data, section, block]
end

# (String, Hash[String, String|Hash[String, String]], Symbol) -> [Hash[String, String|Hash[String, String]], Symbol]
def parse_prepend(line, data, section)
  if section == :prepend
    if line.start_with?(/ *[^; ].*::/)
      section = :end
    else
      data['_prepend'] = data['_prepend'] ? "#{data['_prepend']}\n#{line}" : line
    end
  end
  [data, section]
end

# (String) -> Hash[String, String|Hash[String, String]]
def ahk_to_json(path)
  block = ''
  data = {}
  section = :pre_space
  File.foreach(path).with_index do |line, index|
    line.chomp!
    section = :header if section == :pre_space && line !~ /\A *\z/
    data, section = *parse_header(line, data, section) if section == :header
    data, section, block = *parse_body(line, data, section, block) if section == :body
    data, section = *parse_prepend(line, data, section) if section == :prepend
  end

  data
end

def clean_send(send)
  send.sub("Send '''", %q{Send "'"}).gsub('`', '``').gsub(/([{}^!+#])/, '{\1}')
end

# (Hash[String, String]) -> String
def generate_hotkey_body(block)
  block.dup
       .tap { |block| block.delete('_default') }
       .map do |mode, value|
         "if (mode = '#{mode}')\n" \
         + "    #{value.length == 1 ? clean_send("Send '#{value}'") : "#{value}"}\n" \
         + "  else"
       end
       .join(' ')
       .yield_self do |paragraph|
         if block['_default']
           (paragraph.empty? ? '' : "#{paragraph}\n    ") \
           + (
               if block['_default'].length == 1
                 clean_send("Send '#{block['_default']}'")
               else
                 "#{block['_default']}"
               end
            )
         else
           paragraph[...-7]
         end
       end
end

# (Hash[String, Hash[String, String]]) -> Array[String]
def generate_ahk_body(inverted_json)
  inverted_json.map do |key, block|
    "!#{SHIFT_MAP[SPECIAL_CHARACTERS[key]]}:: {\n  " \
    + (block.values.any? { |value| value.start_with?(/mode ?:=/) } ? "global mode\n  " : '') \
    + generate_hotkey_body(block) \
    + "\n}"
  end
end

# (Hash[String, Hash[String, String]]) -> Array[String]
def generate_plus_body(inverted_json)
  inverted_json.map do |key, block|
    "$#{SHIFT_MAP[SPECIAL_CHARACTERS[key]]}:: {\n  " \
    + (block.values.any? { |value| value.start_with?(/mode ?:=/) } ? "global mode\n  " : '') \
    + block.dup.tap { |block| block.delete('_default') }
           .map do |mode, value|
             "if (mode = '#{mode}_Plus')\n" \
             + "    #{value.length == 1 ? clean_send("Send '#{value}'") : "#{value}"}\n" \
             + "  else" \
           end
           .join(' ')
           .yield_self { |block| "#{block}\n    #{clean_send("Send '#{key}'")}" } \
    + "\n}"
  end
end

# (Hash[String, Hash[String, String]]) -> Hash[String, Hash[String, String]]
def invert_json(json)
  json.dup
      .tap do |json|
        json['_menuPlus'] = json['_menu'].map { |key, option| [key, "#{option[...-1]}_Plus#{option[-1]}"] }
                                         .to_h
      end
      .reduce(Hash.new { |hash, key| hash[key] = {} }) do |hash, (header, block)|
        block.reduce(hash) { |hash, (key, value)| hash.tap { |hash| hash[key][header] = value } }
      end
end

# (Hash[String, String|Hash[String, String]) -> String
def json_to_ahk(json)
  prepend = json.delete('_prepend')
  header = json.delete('_header')
  inverted_json = invert_json(json)

  (
    (header ? [header] : []) \
    + json.map { |header, block| ";;; #{header}\n#{block.map { |key, value| "; #{key} #{value}"}.join("\n")}" } \
    + (prepend ? [prepend] : []) \
    + generate_ahk_body(inverted_json) \
    + generate_plus_body(inverted_json)
  ).map(&:strip).join("\n\n")
end

def main
  path = ARGV[1] || Dir.glob("*.ahk")[0]
  json = ahk_to_json(path)
  File.open(path, 'w') { |file| file.write(json_to_ahk(json)) }
end

main if __FILE__ == $PROGRAM_NAME
