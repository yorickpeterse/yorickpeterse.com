module Zen
  module Plugin
    class Markup
      include ::Ramaze::Helper::CGI

      def markdown(markup)
        # Standardize newlines
        markup.gsub!(/\r\n/, "\n")

        # Allow #{ and } to be used in markup without executing it
        markup.gsub!('#{', '\#\{')
        markup.gsub!('}' , '\}')

        # Enable GitHub like code blocks, taken from here:
        # https://github.com/ivanvanderbyl/markup/commit/52d09d651a423f688651a07b9df999d19e1da8f6#L0R111
        markup.gsub!(/^``` ?([^\r\n]+)?\r?\n(.+?)\r?\n```\r?$/m) do
          "<pre class=\"#{$1}\"><code class=\"#{$1}\">#{h($2)}</code></pre>"
        end

        return RDiscount.new(markup).to_html
      end

    end
  end
end
