require "benchmark"
require "granola"
require "jbuilder"
require "yajl"

MultiJson.use :yajl

Message = Struct.new(
  :content,
  :visitors,
  :author,
  :comments,
  :attachments,
  :created_at,
  :updated_at,
)
Person = Struct.new(:name, :email_address, :url)
Comment = Struct.new(:content, :created_at)
Attachment = Struct.new(:filename, :url)

SERIALIZABLE = Message.new(
  "<p>This is <i>serious</i> monkey business</p>",
  15,
  Person.new(
    "David H.",
    "'David Heinemeier Hansson' <david@heinemeierhansson.com>",
    "http://example.com/users/1-david.json"
  ),
  [
    Comment.new("Hello everyone!", Time.parse("2011-10-29T20:45:28-05:00")),
    Comment.new("To you my good sir!", Time.parse("2011-10-29T20:47:28-05:00")),
  ],
  [
    Attachment.new("forecast.xls", "http://example.com/downloads/forecast.xls"),
    Attachment.new("presentation.pdf", "http://example.com/downloads/presentation.pdf"),
  ],
  Time.parse("2011-10-29T20:45:28-05:00"),
  Time.parse("2011-10-29T20:45:28-05:00"),
)

class MessageSerializer < Granola::Serializer
  def attributes
    {
      content: object.content,
      created_at: object.created_at.iso8601,
      updated_at: object.updated_at.iso8601,
      author: {
        name: object.author.name,
        email_address: object.author.email_address,
        url: object.author.url
      },
      visitors: object.visitors,
      comments: object.comments.map { |comment|
        { content: comment.content, created_at: comment.created_at.iso8601 }
      },
      attachments: object.attachments.map { |attachment|
        { filename: attachment.filename, url: attachment.url }
      }
    }
  end
end

def granola(message)
  MessageSerializer.new(message).to_json
end

def jbuilder(message)
  Jbuilder.encode do |json|
    json.content message.content
    json.(message, :created_at, :updated_at)

    json.author do
      json.name message.author.name
      json.email_address message.author.email_address
      json.url message.author.url
    end

    json.visitors message.visitors

    json.comments message.comments, :content, :created_at

    json.attachments message.attachments do |attachment|
      json.filename attachment.filename
      json.url attachment.url
    end
  end
end

Benchmark.bmbm do |b|
  b.report("jbuilder") { 10_1000.times { jbuilder(SERIALIZABLE) } }
  b.report("granola")  { 10_1000.times { granola(SERIALIZABLE) } }
end
