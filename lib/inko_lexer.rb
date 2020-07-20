# frozen_string_literal: true

module Rouge
  module Lexers
    class Inko < RegexLexer
      title 'Inko'
      desc 'The Inko programming language'
      tag 'inko'
      filenames '*.inko'
      mimetypes 'text/x-inko'

      KEYWORDS = %w[
        object import trait let mut return self throw else impl for as do lambda
        where try try! static match
      ].freeze

      state :root do
        rule(/\s+/m, Text::Whitespace)
        rule(/#.*$/, Comment::Single)
        rule(/"[^"]+"/, Str::Double)
        rule(/'[^']+'/, Str::Single)
        rule(/-?(?:0|[1-9]\d*)\.\d+(?:e[+-]?\d+)?/i, Num::Float)
        rule(/-?(?:0|[1-9]\d*)(?:e[+-]?\d+)?/i, Num::Integer)

        rule(/(\.)(\w+)/) do
          groups Punctuation, Name::Function
        end

        rule(/(\w+)(\()/) do
          groups Name::Function, Punctuation
        end

        rule(/(\w+)(::)/) do
          groups Name::Namespace, Punctuation
        end

        rule(/(\w+)(:)/) do
          groups Str::Symbol, Punctuation
        end

        rule(/(def)(\s+)([^\(|^ ]+)/) do
          groups Keyword, Text, Name::Function
        end

        rule(/(object|trait)(\s+)(\w+)/) do
          groups Keyword, Text, Name::Class
        end

        rule(/@[a-z_]\w*/i, Name::Variable::Instance)
        rule(/[A-Z][a-zA-Z0-9_]*/, Name::Constant)
        rule(/->|!!/, Keyword)
        rule(/(#{KEYWORDS.join('|')})\b/, Keyword)

        rule(/((<|>|\+|-|\/|\*)=?|==)/, Name::Function)

        rule(/(!|\?|\}|\{|\[|\]|\.|,|:|\(|\)|=)/, Punctuation)
        rule(/(\w+)\b/, Text)
      end
    end
  end
end
