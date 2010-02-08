# patch for -- dm-core 0.10.2 & rails 2.3.5
require 'dm-core'
require 'dm-ar-finders'
require 'dm-timestamps'
require 'dm-validations'
DataMapper.setup(:default, "appengine://auto")

# Convert the values from the date and time picker
# to a date or time class that the datastore can accept
def fix_date(hash, property, type)
  total_attributes = 0
  if Date == type
    total_attributes = 3
  else
    total_attributes = 5
  end
  time_string = ""
  1.upto(total_attributes) do |n|
    if n == 1
      time_string << hash[:"#{property}(#{n}i)"]
    elsif n > 1 && n <= 3
      time_string << '-' + hash[:"#{property}(#{n}i)"]
    elsif n == 4
      time_string << ' ' + hash[:"#{property}(#{n}i)"]
    elsif n > 4
      time_string << ':' + hash[:"#{property}(#{n}i)"]
    end
    hash.delete :"#{property}(#{n}i)"
  end
  hash[property] = type.parse(time_string).send("to_#{type.to_s.downcase}")
  hash
end

module DataMapper
  module Resource
    alias :attributes_orig= :attributes=
    # avoid object references in URLs
    def to_param; id.to_s; end
    # silence deprecation warnings
    def new_record?; new?; end
    # avoid NoMethodError
    def update_attributes(*args); update(*args); end
    
    # make sure that all properties of the model that have to do with
    # date or time are converted run through the fix_date converter
    def attributes=(attributes)
      self.class.properties.each do |t| 
        if !(t.name.to_s =~ /.*_at/) && (t.type.to_s =~ /Date|Time/ ) && 
            attributes.include?("#{t.name.to_s}(1i)")
          fix_date(attributes, t.name.to_s, t.type) 
        end
      end 
      self.attributes_orig=(attributes)
    end
  end
end

# DataMapper::Validate
class Dictionary; alias count length; end
 
# Override Extlib::Hook::ClassMethods.inline_call
# to check in the given weak reference
module LocalObjectSpace
  def self.extended(klass)
    (class << klass; self;end).send :attr_accessor, :hook_scopes
    klass.hook_scopes = []
  end
  
  def object_by_id(object_id)
    self.hook_scopes.each do |object|
      return object if object.object_id == object_id
    end
  end
end

# Fix LocalObjectSpace hooks
module Extlib
  module Hook
    module ClassMethods
      extend LocalObjectSpace
      def inline_call(method_info, scope)
        Extlib::Hook::ClassMethods.hook_scopes << method_info[:from]
        name = method_info[:name]
        if scope == :instance
          args = method_defined?(name) && instance_method(name).arity != 0 ? '*args' : ''
          %(#{name}(#{args}) if self.class <= Extlib::Hook::ClassMethods.object_by_id(#{method_info[:from].object_id}))
        else
          args = respond_to?(name) && method(name).arity != 0 ? '*args' : ''
          %(#{name}(#{args}) if self <= Extlib::Hook::ClassMethods.object_by_id(#{method_info[:from].object_id}))
        end
      end
    end
  end
end

# makes the shorthand <%= render @posts %> work
# for collections of DataMapper objects
module ActionView
  module Partials
  alias :render_partial_orig :render_partial
  private
    def render_partial(options = {})
      if DataMapper::Collection === options[:partial]
        collection = options[:partial]
        options[:partial] = options[:partial].first.class.to_s.tableize.singular
        render_partial_collection(options.merge(:collection => collection))
      else
        render_partial_orig(options)      
      end
    end
  end
end

# set a nil date or time when a date cannot be parced
# to avoid exception by ruby via to_date and to_time
module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Converting strings to other objects
      module Conversions
        # 'a'.ord == 'a'[0] for Ruby 1.9 forward compatibility.
        def ord
          self[0]
        end if RUBY_VERSION < '1.9'
        # Form can be either :utc (default) or :local.
        def to_time(form = :utc)
          begin
            ::Time.send("#{form}_time", *::Date._parse(self, false).
                values_at(:year, :mon, :mday, :hour, :min, :sec).
                map { |arg| arg || 0 })
          rescue
            nil
          end
        end
        def to_date
          begin
            ::Date.new(*::Date._parse(self, false).
                values_at(:year, :mon, :mday))
          rescue
            nil
          end
        end
        def to_datetime
          begin
            ::DateTime.civil(*::Date._parse(self, false).
                values_at(:year, :mon, :mday, :hour, :min, :sec).
                map { |arg| arg || 0 })
          rescue
            nil
          end
        end
      end
    end
  end
end
