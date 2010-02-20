class <%= class_name %>
<% max = 2
  presets = {'Text' => ':lazy => false', 'String' => ':length => 500'}
  reserved_dm_names = DataMapper::Resource.instance_methods +
      DataMapper::Resource.private_instance_methods 
  datastore_types  = (DataMapper::Property::PRIMITIVES +
      DataMapper::Types.constants.map{|c| DataMapper::Types.const_get(c)}.
      select{|t| t.respond_to? :primitive}).map {|c| c.to_s.split('::')[-1]}
  Array(attributes).each do |attribute|
    if reserved_dm_names.include? attribute.name
      raise "reserved property name '#{attribute.name}'"
    elsif !datastore_types.include? attribute.type.to_s.camelcase
      raise "unknown property type '#{attribute.type}'"
    end
    max = attribute.name.size if attribute.name.size > max -%>
  end -%>
  include DataMapper::Resource
  
  property :id,<%= " " * (max - 2) %> Serial
<% Array(attributes).each do |attribute|
     klass = attribute.type.to_s.camelcase
     more = presets.has_key?(klass) ? ", #{presets[klass]}" : ''
     pad = max - attribute.name.size
     rad = 13 - klass.size
     %>  property :<%= attribute.name %>, <%= " " * pad
     %><%= "#{klass}" %>, <%= " " * rad %>:required => true<%= more %>
<% end -%>
<% unless options[:skip_timestamps] -%>
  timestamps :at 
<% end -%>
end
