require "timeout"

class Coulis
  class << self
    attr_accessor :_definitions, :_safe_args, :_help
    attr_accessor :bin, :timeout, :no_double_dash, :safe_mode

    def exec(*args, &block)
      self.new.exec *args, &block
    end

    def options(&block)
      self.new(&block)
    end

    def _bin(p)
      @bin = p.to_s
    end

    def _safe_mode(bool=true)
      @safe_mode = bool
    end

    def _timeout(t)
      @timeout = t
    end

    def _no_double_dash
      @no_double_dash = true
    end

    def adef(name, option=nil, &block)
      (@_definitions||={})[name.to_sym] = (option || block )
    end

    def help(help_arg="--help")
      return @_help if @_help && !@_help.empty?

      @_help = options { @args = [help_arg] }.
        exec.split("\n").map(&:strip)
    end

    def _safe_args(&block)
      return @_safe_args if @_safe_args
      @_safe_args ||= []
      if block_given?
        @_safe_args = instance_eval(&block)
      else
        help.each do |l|
          args = l.scan(/(\-{1,2}[\w\-]+)[\W]/)
          unless args.empty?
            args.each{|a| @_safe_args << a[0].to_s}
          end
        end
      end

      return @_safe_args.uniq!
    end
  end

  attr_accessor :args

  def initialize(&block)
    @args ||= []
    self.instance_eval(&block) if block_given?
    self
  end

  def options(&block)
    self.instance_eval(&block)
    self
  end

  def remove(*args)
    new_args = []
    defs = self.class._definitions || {}
    args.each do |a|
      @args.select {|b| b[0] == (defs[a] || argumentize(a))}.each do |b|
        @args.delete(b)
      end
    end
    self
  end

  def reset
    @args = []
  end

  def build_args
    return if @args.nil? or @args.empty?
    @args.flatten.join(" ")
  end

  def argumentize(argname)
    argname = "#{"-" if argname.to_s[0..0] != "-"}#{argname}"
    if !self.class.no_double_dash && argname.size > 2
      argname = "-" + argname.gsub("_", "-")
    end
    argname
  end

  def value_by_arg(argname)
    definition = self.class._definitions[argname.to_sym] || argumentize(argname)

    result = @args.find{|a| a[0].to_s == definition.to_s}
    return if result.nil?

    value = result[1]
    return nil if value.nil?

    if value[0..0] == "'" && value[-1..-1]
      return value[1..-2]
    else
      return value
    end
  end

  def command
    "#{self.class.bin || self.class.to_s.downcase} #{build_args}".strip
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
      @on_error_block.call(res) if @on_error_block.is_a?(Proc)
      after_error($?, res)
    else
      @on_success_block.call(res) if @on_success_block.is_a?(Proc)
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

  def _timeout(value)
    self.class.timeout = value
  end

  def _bin(path)
    self.class.bin = path
  end

  def method_missing(m, *args)
    m = m.to_s.gsub("=", "")
    @args ||= []
    definition = self.class._definitions[m.to_sym] rescue nil
    #puts "m: #{m}, args: #{args.inspect}, definition: #{definition.inspect}"
    arg_name = argumentize(m)

    if args.size == 0
      insert_arg [ definition || arg_name ]
      return self
    end

    if args[0].is_a?(Hash) # no value but options
      full_arg = [ definition || arg_name ]
      opts = args[0]
    else
      q = ""
      q = "'" if args[0].to_s[0..0] != "'"
      full_arg = [ definition || arg_name , "#{q}#{args[0]}#{q}" ]
      opts = args[1]
    end

    insert_arg(full_arg, opts)
    # delete doublon
    if opts && opts.has_key?(:uniq)
      uniq_arg(definition || arg_name)
    end
    self
  end

  def uniq_arg(arg)
    if found = @args.find{|a| a[0] == arg}
      @args.delete found
    end
    self
  end

  def safe_arg?(argname)
    # help parsing issue, so safe mode is off
    return true if(self.class._safe_args || []).empty?
    !self.class._safe_args.find{|a| a.to_s == argname.to_s}.nil?
  end

  def insert_arg(arg, opts=nil)
    if self.class.safe_mode || (opts && opts[:safe] == true)
      return unless safe_arg?(arg[0])
    end

    if !opts
      @args << arg
      return self
    end

    if arg_to_find = opts[:before] || opts[:after]
      found = @args.find{|a|
        a[0] == (self.class._definitions[arg_to_find.to_sym] || arg_to_find)
      }

      if found && index = @args.index(found)
        index+=1 if opts[:after]
        @args.insert(index, arg)
      end
    else
      @args << arg
    end
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
