class Hash

  class << self
    alias_method :from_xml_without_extension, :from_xml
  end

  def self.typecast_xml_value(value, disallowed_types = nil)
    disallowed_types ||= %w(symbol yaml)

    case value.class.to_s
    when 'Hash'
      if value.include?('type') && !value['type'].is_a?(Hash) && disallowed_types.include?(value['type'])
        raise DisallowedType, value['type']
      end

      if value['type'] == 'array'
        _, entries = Array.wrap(value.detect { |k,v| not v.is_a?(String) })
        if entries.nil? || (c = value['__content__'] && c.blank?)
          []
        else
          case entries.class.to_s   # something weird with classes not matching here.  maybe singleton methods breaking is_a?
          when "Array"
            entries.collect { |v| typecast_xml_value(v, disallowed_types) }
          when "Hash"
            [typecast_xml_value(entries, disallowed_types)]
          else
            raise "can't typecast #{entries.inspect}"
          end
        end
      elsif value['type'] == 'file' || 
          (value["__content__"] && (value.keys.size == 1 || value["__content__"].present?))
        content = value["__content__"]
        if parser = ActiveSupport::XmlMini::PARSING[value["type"]]
          parser.arity == 1 ? parser.call(content) : parser.call(content, value)
        else
          content
        end
      elsif value['type'] == 'string' && value['nil'] != 'true'
        ""
      elsif value.blank? || value['nil'] == 'true'
        nil
        # If the type is the only element which makes it then
        # this still makes the value nil, except if type is
        # a XML node(where type['value'] is a Hash)
      elsif value['type'] && value.size == 1 && !value['type'].is_a?(::Hash)
        nil
      else
        xml_value = Hash[value.map { |k,v| [k, typecast_xml_value(v, disallowed_types)] }]
        xml_value["file"].is_a?(StringIO) ? xml_value["file"] : xml_value
      end
    when 'Array'
      value.map! { |i| typecast_xml_value(i, disallowed_types) }
      value.length > 1 ? value : value.first
    when 'String'
      value
    else
      raise "can't typecast #{value.class.name} - #{value.inspect}"
    end
  end

  def self.from_xml(xml)
    obj = remove_pagination_attributes(::ActiveSupport::XmlMini.parse(xml)).deep_transform_keys {|k| k.to_s.tr("-", "_") }
    typecast_xml_value(obj)
  end

  def self.remove_pagination_attributes(deserialized_xml)
    if deserialized_xml.values.size == 1 && deserialized_xml.values.first['type'] == 'array'
      clone = deserialized_xml.clone
      clone.values.first.delete 'per_page'
      clone.values.first.delete 'current_page'
      clone.values.first.delete 'total_entries'
      return clone
    end
    deserialized_xml
  end

end
