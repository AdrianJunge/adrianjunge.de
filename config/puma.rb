threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

plugin :tmp_restart
plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"

pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
