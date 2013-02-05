require 'redcarpet'

##
# Custom HTML renderer that supports goodies such as headers with IDs set.
#
class CustomRedcarpet < Redcarpet::Render::HTML
  ##
  # @param [String] text The text of the header.
  # @param [Numeric] level The header level (`h2`, `h3`, etc).
  # @return [String]
  #
  def header(text, level)
    identifier = text.downcase.squeeze(' ').gsub(/\s+/, '_')
    values     = [level, identifier, text, level]

    return '<h%s id="%s">%s</h%s>' % values
  end
end # CustomRedcarpet
