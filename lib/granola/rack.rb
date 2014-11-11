require "digest/md5"
require "time"
require "granola"
require "granola/helper"
require "granola/caching"

# Mixin to render JSON in the context of a Rack application. See the #json
# method for the specifics.
module Granola::Rack
  def self.included(base)
    base.send(:include, Granola::Helper)
  end

  # Public: Renders a JSON representation of an object using a
  # Granola::Serializer. This takes care of setting the `Last-Modified` and
  # `ETag` headers if appropriate, and of controlling whether the object should
  # be rendered at all or not (issuing a 304 response in this case).
  #
  # This expects the class mixing in this module to implement an `env` method,
  # that should be a Rack environment Hash.
  #
  # object - An object to serialize into JSON.
  #
  # Keywords:
  #   with:           A specific serializer class to use. If this is `nil`,
  #                   `Helper.serializer_class_for` will be used to infer the
  #                   serializer class.
  #   **json_options: Any other keywords passed will be forwarded to the
  #                   serializer's `#to_json` call.
  #
  # Raises NameError if no specific serializer is provided and we fail to infer
  #   one for this object.
  # Returns a Rack response tuple.
  def json(object, with: nil, **json_options)
    serializer = serializer_for(object, with: with)
    headers = {}

    if serializer.last_modified
      headers["Last-Modified".freeze] = serializer.last_modified.httpdate
    end

    if serializer.cache_key
      headers["ETag".freeze] = Digest::MD5.hexdigest(serializer.cache_key)
    end

    stale_check = StaleCheck.new(
      env,
      last_modified: headers["Last-Modified".freeze],
      etag: headers["ETag".freeze]
    )

    if stale_check.fresh?
      [304, headers, []]
    else
      json_string = serializer.to_json(json_options)
      headers["Content-Type".freeze] = serializer.mime_type
      headers["Content-Length".freeze] = json_string.length.to_s
      [200, headers, [json_string]]
    end
  end

  # Internal: Check whether a request is fresh or stale by both modified time
  # and/or etag.
  class StaleCheck
    # Internal: Get the env Hash of the request.
    attr_reader :env

    # Internal: Get the Time at which the domain model was last-modified.
    attr_reader :last_modified

    # Internal: Get the String with the ETag ggenerated by this domain model.
    attr_reader :etag

    IF_MODIFIED_SINCE = "HTTP_IF_MODIFIED_SINCE".freeze
    IF_NONE_MATCH = "HTTP_IF_NONE_MATCH".freeze

    # Public: Initialize the check.
    #
    # env - Rack's env Hash.
    #
    # Keywords:
    #   last_modified: The Time at which the domain model was last modified, if
    #                  applicable (Defaults to `nil`).
    #   etag:          The HTTP ETag for this domain model, if applicable
    #                  (Defaults to `nil`).
    def initialize(env, last_modified: nil, etag: nil)
      @env = env
      @last_modified = last_modified
      @etag = etag
    end

    # Public: Checks whether the request is fresh. A fresh request is one that
    # is stored in the client's cache and doesn't need updating (so it can be
    # responded to with a 304 response).
    #
    # Returns Boolean.
    def fresh?
      fresh_by_time? || fresh_by_etag?
    end

    # Public: Returns a Boolean denoting whether the request is stale (i.e. not
    # fresh).
    def stale?
      !fresh?
    end

    # Internal: Checks if a request is fresh by modified time, if applicable, by
    # comparing the `If-Modified-Since` header with the last modified time of
    # the domain model.
    #
    # Returns Boolean.
    def fresh_by_time?
      return false unless env.key?(IF_MODIFIED_SINCE) && !last_modified.nil?
      Time.parse(last_modified) <= Time.parse(env.fetch(IF_MODIFIED_SINCE))
    end

    # Internal: Checks if a request is fresh by etag, if applicable, by
    # comparing the `If-None-Match` header with the ETag for the domain model.
    #
    # Returns Boolean.
    def fresh_by_etag?
      return false unless env.key?(IF_NONE_MATCH) && !etag.nil?
      if_none_match = env.fetch(IF_NONE_MATCH, "").split(/\s*,\s*/)
      return false if if_none_match.empty?
      return true if if_none_match.include?("*".freeze)
      if_none_match.any? { |tag| tag == etag }
    end
  end
end
