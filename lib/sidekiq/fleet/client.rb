module Sidekiq
  module Fleet
    class Client

      def initialize(options = {})
        @options      = options
        @pids         = []
        @stop_signal  = options.fetch(:stop_signal, :TERM)
        @count        = options.fetch(:count, process_count)

        begin
          trap @stop_signal.to_s do
            handle_signal(sig)
          end
        rescue ArgumentError
          puts "Signal #{sig} not supported"
        end
      end

      def start
        stop if @pids.size > 0
        @count.times do |precess_index|
          command = cmd
          puts "Running [0] - #{command}"
          pid = spawn({}, command)
        end
      end

      def stop
        if pids.size > 0
          puts "Preparing to stop #{pids.size} sidekiq processes..."
          @pids.each do |pid|
            puts "'Stopping sidekiq pid=#{pid} ...'"
            begin
              Process.kill @stop_signal, pid
            rescue Errno::ESRCH
              puts "Sidekiq process id=#{pid} not found"
              @pids.delete(pid)
            end
          end
        else
          puts "Lost Sidekiq processes..."
        end
      end

      protected

        def handle_signal(sig)
          puts "Got signal #{sig}..."
          stop
        end

        def queue_params
          params = @options[:queue]
          params = [params] unless params.is_a?(Array)
          params.collect {|param| "--queue #{param}"}.join(" ")
        end

        def cmd
          command = ['bundle exec sidekiq']
          command << "--logfile #{@options[:logfile]}"          if @options[:logfile]
          command << queue_params                               if @options[:queue]
          command << "-C #{@options[:config]}"                  if @options[:config]
          command << "--verbose"                                if @options[:verbose]
          command << "--environment #{@options[:environment]}"  if @options[:environment]
          command << "--timeout #{@options[:timeout]}"          if @options[:timeout]
          command << "--require #{@options[:require]}"          if @options[:require]
          command << "--concurrency #{@options[:concurrency]}"  if @options[:concurrency]
          command.join(' ')
        end

        def process_count
          return ENV['SK_PROCESS_COUNT'].to_i unless ENV['SK_PROCESS_COUNT'].to_i == 0

          case RbConfig::CONFIG['host_os']
          when /linux/
            `grep processor /proc/cpuinfo | wc -l`.to_i
          when /darwin9/
            `hwprefs cpu_count`.to_i
          when /darwin/
            ((`which hwprefs` != '') ? `hwprefs thread_count` : `sysctl -n hw.ncpu`).to_i
          when /freebsd/
            `sysctl -n hw.ncpu`.to_i
          end
        end

    end
  end
end
