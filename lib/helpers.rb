include Nanoc::Helpers::Blogging
include Nanoc::Helpers::Rendering

##
# Returns a String containing the date in a fixed format.
#
# @param [String] date
# @return [String]
#
def format_date(date)
  return attribute_to_time(date).dup.utc.iso8601
end

##
# Returns a `<time>` tag for the given date string.
#
# @param [String] date
# @return [String]
#
def date_tag(date)
  human_format   = attribute_to_time(date).to_s
  machine_format = format_date(date)

  return '<time datetime="%s">%s</time>' % [machine_format, human_format]
end
