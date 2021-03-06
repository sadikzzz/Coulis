# Coulis: a simple CLI Wrapper #

With Coulis, you can create a wrapper for any CLI application very easily.

## Install ##

	sudo gem install coulis

## Getting started ##

To create a wrapper class, just create a class which inerits from the `Coulis` class. Example with the curl application:

``` ruby
class Curl < Coulis
  adef :user,    "-u"
  adef :request, "-X"
  adef :data,    "-d"
  adef :header,  "-H"
  adef :agent,   "-A"
  adef :form,    "-F"
  adef :proxy,   "-x"
  adef :head,    "-I"
end
```

To use the created class:

``` ruby
Curl.options {
  user    "user:passwd"
  request "POST"
  data    "url=http://site.com/video.avi"
  data    "title=MyTitle"
  url     "https://heywatch.com/download.json"
}.exec do |out|
  puts out
end
```

## Arguments ##

You can define an argument with the method `adef`. Note that all other short and long parameters (not defined in the class) are still available via their name. Example with the parameters `-e` and `--url`:

``` ruby
Curl.options {
  agent "Coulis / 0.1.2"
  e     "http://site.com/referer" # -e => referer
  url   "http://google.com"
}.exec {...}
```

You can add other arguments or delete them before calling `exec`.

``` ruby
curl = Curl.options { url "http://google.com" } # => "curl --url 'http://google.com'"
curl.options { agent "Coulis / 0.1.2" }         # => "curl --url 'http://google.com' -A 'Coulis / 0.1.2'"
curl.proxy "proxyip:port"                       # => "curl --url 'http://google.com' -A 'Coulis / 0.1.2' -x 'proxyip:port'"

curl.remove :proxy                              # => "curl --url 'http://google.com' -A 'Coulis / 0.1.2'"
```

## Parsing Output ##

Define the method `parse_output` in your class to automatically parse the output, here is an example with `nslookup`:

``` ruby
class NSLookup < Coulis
  def parse_output(output)
    output.split("\n").
      map{|x| x.match(/Address: ([0-9\.]+)/)[1] rescue nil}.
      compact
  end
end

NSLookup.options {
  @args = ["google.com"]
}.exec do |ips|
  p ips # => ["209.85.148.106", "209.85.148.103", "209.85.148.147", "209.85.148.99", "209.85.148.105", "209.85.148.104"]
end
```

## Timeout ##

Add a special argument `_timeout` if you don't want the process to run more than x seconds:

``` ruby
Curl.options {
  url "http://site.com/superlongaction"
  _timeout 2
}.exec {...}
```

Will raise a `Timeout::Error`.

## Execution ##

`exec` can be used with or without a block. If used without a block, it will return the output directly, otherwise an instance of `Process::Status`.

``` ruby
process = Curl.options {
  url "http://google.com"
}.exec {...}

puts process.exitstatus # => 0
```

``` ruby
page = Curl.options {
  url "http://google.com"
}.exec

puts page # => HTML of the google page
```

## Success and Error Events ##

You can use `on_success` and `on_error` to respectively execute code after a successful command exectution and after an error (when existstatus is != 0).
It's important that exec comes at the very end of the chain.

``` ruby
Curl.options {
  url "http://google.com"
}.on_success {|out|
  puts "Page downloaded"
}.exec
```

``` ruby
Curl.options {
  url "http://baddomainnamezzz.com"
}.on_success {|out|
  puts "Page downloaded"
}.on_error {|out|
  puts "Error downloading the page"
}.exec
```

You can also do something after success and error but at the class level via `after_success` and `after_error` methods. Here is an example:

``` ruby
class Curl < Coulis
  def after_success(proc, out)
    puts "After Success"
    # do something
  end

  def after_error(proc, out)
    puts "After error"
    # do something
  end
end

Curl.options {
  url "http://baddomainnamezzz.com"
}.on_success {|out|
  puts "Page downloaded"
}.on_error {|out|
  puts "Error downloading the page"
}.exec
```
```
Error downloading the page
After error
```

## Safe mode ##

Safe mode is a feature that is used to prevent non existing argument to be added to the command line. You have two ways to use it: in the definition of your class via the method `_safe_mode`, and in the argument option `:safe => true`.

By default we parse the help output of the program so basically, every arguments that start with "-" are valid. If you're not statisfied by the default parsing and you're surely right, you can use the method `_safe_args`.

So here we define `_safe_mode` in the class itself so all the arguments added are valid.

``` ruby
class CurlSafe < Coulis
  _bin "curl"
  _safe_mode
end

curl = CurlSafe.options {
  url "http://google.com"
  fake_arg "nop"
}

puts curl.command # => curl --url 'http://google.com'
```

Here, only `fake_arg` is checked.

``` ruby
curl = Curl.options {
  url "http://google.com"
  fake_arg "nop", :safe => true
  fake_arg_ok "yes"
}

puts curl.command # => curl --url 'http://google.com' --fake-arg-ok 'yes'
```

Now let's define the safe args ourself:

``` ruby
class CurlSafe < Coulis
  _bin "curl"
  _safe_mode
  
  # we only want to make GET request with basic auth
  # nothing more will be permitted
  _safe_args {
    %w(--url --user)
  }
end

curl = CurlSafe.options {
  url "http://google.com"
  fake_arg "nop"
  fake_arg_ok "yes"
}

puts curl.command # => curl --url 'http://google.com'
```

Released under the [MIT license](http://www.opensource.org/licenses/mit-license.php).

Author: Bruno Celeste [@sadikzzz](http://twitter.com/sadikzzz)