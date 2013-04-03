minute = 60

ruby_plist = [
  '~/home/alex/Projects/3rose/3rose-app/rails s',
  '~/home/alex/Projects/3rose/3rose-app/bundle exec rake app_worker',
  '~/home/alex/Projects/3rose/3rose-core/rails s --port=????',
  '~/home/alex/Projects/3rose/3rose-core/ruby core_worker_runner.rb'
]

while true
  pids = %x[pgrep ruby].split("\n")
  if pids.length == ruby_plist.length
    p "#{Time.now} running core_worker..."
    %x[cd ~/Projects/3rose/3rose-core]
    %x[source ~/.profile]
    %x[bundle exec rake core_worker]
  end
  sleep 1*minute
end
