require "timeout"

class Coulis
  class << self
    attr_accessor :args, :_definitions, :_bin, :timeout, :no_double_dash

    def exec(*args, &block)
      self.new.exec *args, &block
    end

    def options(&block)
      self.new(&block)
    end

    def bin(p)
      @_bin = p.to_s
    end

    def _timeout(t)
      @timeout = t
    end

    def _no_double_dash
      @no_double_dash = true
    end

    def adef(name, option=nil, &block)
      (@_definitions||={})[name.to_sym] = (option || Proc.new { self.instance_eval(&block).flatten })
    end

    def method_missing(m, args=nil)
      m = m.to_s.gsub("=", "")
      @args ||= []
      definition = @_definitions[m.to_sym] rescue nil

      #puts "m: #{m}, def: #{definition.inspect} | args:#{args}"
      if definition.is_a?(Proc)
        definition.call
      else
        arg_name = "#{"-" if m[0..0] != "-"}#{m}"
        arg_name = "-" + arg_name.gsub("_", "-") if !@no_double_dash && arg_name.size > 2

        if args.to_s.empty?
          @args << [ definition || arg_name ]
        else
          q = ""
          q = "'" if args.to_s[0..0] != "'"
          @args << [ definition || arg_name , "#{q}#{args}#{q}" ]
        end
      end
    end
  end

  attr_accessor :args

  def initialize(&block)
    self.class.instance_eval(&block) if block_given?
    @args = self.class.args
    self.class.args = []
    self
  end

  def options(&block)
    self.class.args = @args
    self.class.new(&block)
  end

  def remove(*args)
    new_args = []
    defs = self.class._definitions || {}
    args.each do |a|
      @args.select {|b| b[0] == (defs[a] || "-#{a}")}.each do |b|
        @args.delete(b)
      end
    end
    self.class.args = @args
    self
  end

  def reset
    @args = []
    self.class.args = []
  end

  def build_args
    return if @args.nil? or @args.empty?
    @args.flatten.join(" ")
  end

  def command
    "#{self.class._bin || self.class.to_s.downcase} #{build_args}".strip
  end

  def fire_command(&block)
    puts command + " (timeout: #{self.class.timeout || -1}) + #{block_given?}" if $DEBUG
    res = ""
    IO.popen(command + "  3>&2 2>&1") do |pipe|
      pipe.each("\r") do |line|
        res << line
        if block_given?
          yield parse_output(line)
        end
      end
    end
    if $?.exitstatus != 0
      @on_error_block.call($?, res) if @on_error_block.is_a?(Proc)
      after_error($?, res)
    else
      @on_success_block.call($?, res) if @on_success_block.is_a?(Proc)
      after_success($?, res)
    end
    return (block_given? ? $? : parse_output(res))
  end

  def parse_output(output)
    output
  end

  def on_error(&block)
    @on_error_block = block
    self
  end

  def on_success(&block)
    @on_success_block = block
    self
  end

  def after_success(proc, res); end
  def after_error(proc, res); end

  def method_missing(m, args=nil)
    self.class.args = @args
    self.class.method_missing(m, args)
    @args = self.class.args
    self
  end

  def inspect
    "#<#{self.class.to_s} command=#{command} timeout=#{self.class.timeout || -1}>"
  end

  def exec(*args, &block)
    if args.size > 0
      i = 0
      (args.size / 2).times do
        self.class.send(args[i], args[i+1])
        i+=2
      end

      @args = self.class.args
      self.class.args = []
    end

    if self.class.timeout
      Timeout::timeout(self.class.timeout) do
        fire_command(&block)
      end
    else
      fire_command(&block)
    end
  end
end
