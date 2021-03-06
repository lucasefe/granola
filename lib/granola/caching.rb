require "granola"

module Granola
  # Mixin to add caching-awareness to Serializers.
  module Caching
    # Public: Provides a key that's unique to the current representation of the
    # JSON object generated by the serializer. This will be MD5'd to become the
    # ETag header that will be sent in responses.
    #
    # Returns a String or `nil`, indicaing that no ETag should be sent.
    def cache_key
    end

    # Public: Provides the date of last modification of this entity. This will
    # become the Last-Modified header that will be sent in responses, if
    # present.
    #
    # Returns a Time or `nil`, indicating that no Last-Modified should be sent.
    def last_modified
    end
  end

  class Serializer
    include Caching
  end

  class List < Serializer
    def cache_key
      all = @list.map(&:cache_key).compact
      all.join("-") if all.any?
    end

    def last_modified
      @list.map(&:last_modified).compact.sort.last
    end
  end
end
