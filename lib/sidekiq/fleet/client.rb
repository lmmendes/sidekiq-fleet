module Sidekiq
  module Fleet
    class Client

      attr_reader :pids, :stop_signal, :options

      def initialize(options = {})
        @options          = options
        @pids             = []
        @stop_signal      = options.fetch(:stop_signal, :TERM)
        @count            = options.fetch(:count, process_count)
        @max_process_size = options.fetch(:max_process_size, 256)

        begin
          trap @stop_signal.to_s do
            handle_signal(sig)
          end
        rescue ArgumentError
          puts "Signal #{sig} not supported"
        end
      end

      def start
        stop if pids.size > 0
        @count.times do |process_index|
          spawn_child(process_index)
        end
      end

      def stop
        if pids.size > 0
          puts "Preparing to stop #{pids.size} sidekiq processes..."
          pids.each do |pid|
            puts "'Stopping sidekiq pid=#{pid} ...'"
            begin
              kill(pid)
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

      def watch_children
        return if @watch_children
        @watch_children = true
        Thread.new do
          @pids.each do |pid|
            size = ProcessMemory.new(pid).mb
            if size  == 0
              @pids.delete(pid)
              @pids << spawn_child(process_index)
            elsif size > @max_process_size
              kill(pid)
              @pids.delete(pid)
              @pids << spawn_child(process_index)
            end
          end
          sleep(10)
        end
      end

      def handle_signal(sig)
        puts "Got signal #{sig}..."
        stop
      end

      def kill(pid)
        Process.kill 'USR1', pid
        sleep 10
        Process.kill 'TERM', pid
      end

      def spawn_child(process_index)
        command = cmd
        puts "Running child=#{process_index} - #{command}"
        # spawn the child process and returns it's pid
        spawn({}, command)
      end

      def queue_params
        params = options[:queue]
        params = [params] unless params.is_a?(Array)
        params.collect {|param| "--queue #{param}"}.join(" ")
      end

      def cmd
        command = ['bundle exec sidekiq']
        command << "--logfile #{@options[:logfile]}"          if @options[:logfile]
        command << queue_params                               if @options[:queue]
        command << "--verbose"                                if @options[:verbose]
        command << "--environment #{@options[:environment]}"  if @options[:environment]
        command << "--timeout #{@options[:timeout]}"          if @options[:timeout]
        command << "--require #{@options[:require]}"          if @options[:require]
        command << "--concurrency #{@options[:concurrency]}"  if @options[:concurrency]
        command.join(' ')
      end

      def process_count
        case RbConfig::CONFIG['host_os']
        when /linux/
          `getconf _NPROCESSORS_ONLN`.to_i
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
