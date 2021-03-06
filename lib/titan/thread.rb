require "yaml"

module Titan
  #
  # Titan::Thread helps you creating daemon threads that are independent from your application.
  # Each Titan::Thread is identified by an id that you can either pass on initialization or
  # that gets created automatically.
  #
  class Thread
    TITAN_FILE = File.expand_path('.titan', '~')

    attr_accessor :id, :pid

    @@threads = {}

    #
    # Creates a new daemonized thread
    #
    def initialize(options = {}, &block)
      @id   = options[:id] || __id__
      @pid  = Process.fork do
        # ignore interrupts
        Signal.trap('HUP', 'IGNORE')
        # execute the actual programm
        block.call
        # exit the forked process cleanly
        Kernel.exit!
      end

      Process.detach(@pid)
      Titan::Thread.add(self)
    end

    #
    # Kills the daemonized thread
    # @param [String] Signal to send to the process. Eg: 'KILL','QUIT','TERM','INT'
    #
    def kill(sig='KILL')
      Process.kill(sig, @pid)
    end

    #
    # Returns whether the thread is alive or not
    #
    def alive?
      Process.getpgid(@pid)
      true
    rescue Errno::ESRCH
      false
    end

    def id=(id)
      @@threads.delete(@id)
      @id = id
      @@threads[id] = self
      Titan::Thread.save_threads
    end

    class << self
      def add(thread)
        load_threads
        @@threads[thread.id] = thread
        save_threads
        thread
      end

      #
      # Returns a thread that has the given id
      #
      def find(id)
        load_threads
        @@threads[id]
      end

      def kill(id)
        find(id).kill
      end

      #
      # Returns all Titan-managed threads
      #
      def all
        load_threads
        @@threads
      end

      #
      # Loads threads from the TITAN_FILE
      #
      def load_threads
        return unless File.exists?(TITAN_FILE)
        @@threads = YAML::load(File.open(TITAN_FILE)) || {}
      end

      #
      # Saves threads to the TITAN_FILE
      #
      def save_threads
        File.open(TITAN_FILE, 'w') { |file| file.write(YAML::dump(@@threads)) }
      end

      #
      # Removes threads that are not living anymore
      #
      def remove_dead_threads
        @@threads.delete_if { |thread_id,thread| !thread.alive? }
        save_threads
        @@threads
      end
    end
  end
end
