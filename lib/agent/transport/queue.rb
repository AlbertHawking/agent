module Agent
  module Transport

    class ConcurrentHash < Hash
      def initialize; super; @mutex = Mutex.new; end
      def [](*args);  @mutex.synchronize { super }; end
      def []=(*args); @mutex.synchronize { super }; end
    end

    class Queue

      @@registry = ConcurrentHash.new

      def initialize(name, max = 1)
        raise ArgumentError, "queue size must be at least 1" unless max > 0

        @name = name
        @max = max

        if !@@registry[@name]
          @@registry[@name] = {
            :que => [],
            :wait => [],
            :mutex => Mutex.new,
            :cvar => ConditionVariable.new
          }
        end
      end

      def data;  @@registry[@name]; end
      def que;   data[:que];        end
      def wait;  data[:wait];       end
      def mutex; data[:mutex];      end
      def cvar;  data[:cvar];       end

      def max;    @max;     end
      def size;   que.size; end
      def length; que.size; end

      def push?; max > size; end
      def push(obj)
        mutex.synchronize {
          while true
            break if que.length < @max
            cvar.wait(mutex)
          end

          que.push obj
          cvar.signal
        }
      end
      alias << push
      alias enq push

      def pop?; size > 0; end
      def pop(*args)
        mutex.synchronize {
          while true
            break if !que.empty?
            cvar.wait(mutex)
          end

          retval = que.shift
          cvar.signal

          retval
        }
      end
      alias shift pop
      alias deq pop

      def async?; @max > 1; end

      def send(msg, nonblock = false)
        raise ThreadError, "buffer full" if nonblock && que.length >= @max
        push(msg)
      end

      def receive(nonblock = false)
        raise ThreadError, "buffer empty" if nonblock && que.empty?
        pop
      end

      def close
        @@registry.delete @name
      end

    end
  end
end
