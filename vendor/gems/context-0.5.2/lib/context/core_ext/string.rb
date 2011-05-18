class String
  # Replaces spaces and tabs with _ so we can use the string as a method name
  # Also replace dangerous punctuation
  def to_method_name
    downcased = self.downcase
    downcased.gsub!(/[\s:',;!#\-\(\)\.\?]+/,'_')
    downcased
  end
  
  # Borrowed from +camelize+ in ActiveSupport
  def to_module_name
    meth_name = self.to_method_name
    meth_name.gsub!(/\/(.?)/) { "::#{$1.upcase}" }
    meth_name.gsub!(/(?:^|_)(.)/) { $1.upcase }
    meth_name
  end
  
  # Borrowed from +camelize+ in ActiveSupport
  def to_class_name
    meth_name = self.to_method_name
    meth_name.gsub!(/\/(.?)/) { "#{$1.upcase}" }
    meth_name.gsub!(/(?:^|_)(.)/) { $1.upcase }
    meth_name
  end
end
