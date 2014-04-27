include Nanoc::Helpers::Blogging
include Nanoc::Helpers::Rendering
include Nanoc::Helpers::LinkTo

##
# Returns a `<time>` tag for the given date string.
#
# @param [String] date
# @return [String]
#
def date_tag(date)
  date = attribute_to_time(date).dup.utc

  machine_format = date.iso8601
  human_format   = date.strftime('%B %d, %Y')

  return '<time datetime="%s">%s</time>' % [machine_format, human_format]
end
