# WORK-IN-PROGRESS


require 'net/http'
require 'json'
require 'date'

host = ''
auth_token = ''
app_name = ''
http_timeout = 300

# first occurrence before end date + not resolved or resolved after start date
# see https://github.com/errbit/errbit/blob/master/app/controllers/api/v1/problems_controller.rb#L11
end_date = '2013-12-31T23:59:59-04:00'
start_date = '2010-10-01T01:00:00-04:00'

# zahmad: start/end kind of useless, so let's filter ourselves later
#uri = URI.parse("#{host}/api/v1/problems?auth_token=#{auth_token}&app_name=#{app_name}&start_date=#{start_date}&end_date=#{end_date}")
uri = URI.parse("#{host}/api/v1/problems?auth_token=#{auth_token}&app_name=#{app_name}")

req = Net::HTTP::Get.new(uri.request_uri)
resp = Net::HTTP.start(uri.hostname, uri.port) { |http|
  http.read_timeout = http_timeout
  http.request(req)
}
json = JSON.parse(resp.body)


this_morning = Date.today.to_time
yesterday_morning = this_morning - (60 * 60 * 24)

all = json.select { |p| 
  last_notice = DateTime.parse(p['last_notice_at']).to_time
  # most recent unresolved occurrences from yesterday
  last_notice >= yesterday_morning && last_notice <= this_morning
}

open = all.reject { |p| p['resolved'] }
resolved = all.select { |p| p['resolved'] }

undefined_method = open.select { |p| p['message'].downcase.include?('undefined method') }
missing_template = open.select { |p| p['message'].downcase.include?('missing template') }
erx = open.select { |p| msg = p['message'].downcase;  msg.include?('erx iframe') || msg.include?('erx::') }
tas_bomb = open.select { |p| p['message'].downcase.include?('multijson::parseerror') }
mysql = open.select{ |p| p['message'].downcase.include?('mysql') }
deadlock = mysql.select{ |p| p['message'].downcase.include?('deadlock') }
lost_conn = mysql.select{ |p| p['message'].downcase.include?('lost connection') }

def pcount(label, list)
  puts "  #{label}: " << list.group_by {|p| p['app_name']}.values.collect { |a| "#{a.first['app_name']} (#{a.count})" }.join(', ')
end

puts "Errbit Report for #{yesterday_morning.to_date}:"
puts "  open: #{open.count}"
puts "  resolved: #{resolved.count}"
puts ""
pcount('undefined method', undefined_method)
pcount('missing template', missing_template)
pcount('erx related', erx)
pcount('tas client errors', tas_bomb)
pcount('mysql errors', mysql)
pcount('deadlocks', deadlock)
pcount('lost connection', lost_conn)


# fields:
#   _id, app_id, app_name, comments_count, created_at, environment, error_class, first_notice_at, hosts, issue_link, issue_type, 
#   last_deploy_at, last_notice_at, message, messages, notices_count, resolved, resolved_at, updated_at, user_agents, where

puts ""
puts "Errors by frequency:"
puts "  application|count|message|first_notice|last_notice"
open.sort_by { |p| p['notices_count'] }.reverse.each do |p|
  #puts [p['notices_count'], p['message'][0..75], p['first_notice_at'], p['last_notice_at']].join(', ')
  puts [p['app_name'], p['notices_count'], p['message'][0..75].gsub("\n", ''), p['first_notice_at'], p['last_notice_at']].join(', ')
end

