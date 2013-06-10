include Nanoc::Helpers::Blogging
include Nanoc::Helpers::Rendering

##
# Returns a String containing the date in a fixed format.
#
# @param [String] date
# @return [String]
#
def format_date(date)
  return attribute_to_time(date).dup.utc.strftime('%Y-%m-%d %R %Z')
end

##
# Returns a `<time>` tag for the given date string.
#
# @param [String] date
# @return [String]
#
def date_tag(date)
  machine_format = attribute_to_time(date).to_s
  human_format   = format_date(date)

  return '<time pubdate="%s" datetime="%s">%s</time>' \
    % [human_format, machine_format, human_format]
end
