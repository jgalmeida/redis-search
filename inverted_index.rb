require 'test/unit'
require 'redis'

module DocumentFactory

  def create_document(text)
    doc = Document.new(text)
    doc.save
    doc
  end

end

class Document
  attr_accessor :id, :text

  def initialize(text)
    @text  = text
  end

  def save
    redis = Redis.current

    @id = redis.incr("documents::uid")
    redis.sadd("all_documents", @id)
    redis.hmset("document:#{@id}", :id, @id, :text, @text)
  end

  def self.__instantiate__(id, text)
    instance = new(text)
    instance.instance_eval { @id = id }
    instance
  end
end

class Indexer

  def initialize(type, redis = Redis.current)
    @type  = type
    @redis = redis
  end

  def analyze(document)
    tokens = document.text.split(" ")

    tokens.each do |token|
      normalized_token = normalize_word(token)

      unless normalized_token.empty?
        @redis.sadd "fulltext:#{normalized_token}", document.id
      end
    end
  end

  def clear
    all_documents_ids = @redis.smembers "all_documents"

    all_documents_ids.each do |id|
      @redis.del "document:#{id}"
    end

    @redis.del "documents::uid"
    @redis.del "all_documents"
  end

  def normalize_word(word)
    word.tr('^A-Za-z0-9', '').downcase
  end

end

class FullText

  class << self
    TEMP_KEY_TTL = 2 #SECONDS

    def index(type, &block)
      block.call Indexer.new(type)
    end

    def clear(type)
      Indexer.new(type).clear
      #ALERT - USE TTL
      Redis.current.flushdb
    end

    def search(word)
      redis = Redis.current
      tokens = word.split
      sets   = []

      tokens.each_with_index do |token, index|
        temp_set_key = "temp_search#{index}"
        index = "fulltext:#{token}"

        sets << temp_set_key

        documents_ids = redis.smembers index

        if documents_ids.any?
          (redis.sadd temp_set_key, (redis.smembers index))
          redis.expire temp_set_key, TEMP_KEY_TTL
        end
      end

      documents_ids = redis.sunion(*sets)

      documents_ids.uniq!

      instantiate_documents(documents_ids)
    end

    def indexed_documents
      redis = Redis.current
      all_documents_ids = redis.smembers "all_documents"

      instantiate_documents(all_documents_ids)
    end

    def instantiate_documents(ids)
      redis = Redis.current

      ids.map do |id|
        doc = redis.hgetall "document:#{id}"
        Document.__instantiate__(doc["id"], doc["text"])
      end
    end

  end

end

class FullTextSearch < Test::Unit::TestCase
  include DocumentFactory

  def setup
    @gym_haters_text = create_document('Today I will go to the Gym. Really, I can\'t stand weight lifting. I love Redis.')
    @my_bio          = create_document('Thiago Teixeira Dantas will show you some naive inverted index attempt using redis. Are you READY ?')

    FullText.index(:documents) do |index|
      index.analyze @gym_haters_text
      index.analyze @my_bio
    end

  end

  def teardown
    FullText.clear(:documents)
  end

  def test_number_of_indexed_document
    assert_equal 2, FullText.indexed_documents.length
  end

  def test_searching_ignoring_case
    documents = FullText.search 'ready'
    assert_equal 1, documents.length
    assert_equal @my_bio.text, documents.first.text
  end

  def test_simple_search
    documents = FullText.search 'naive'
    assert_equal 1, documents.length
  end

  def test_make_indexed_text_searchable_like_OR_expression
    documents = FullText.search 'naive inverted'
    assert_equal 1, documents.length
  end

  def test_ranking_texts
    documents = FullText.search 'redis thiago'
    assert_equal 2, documents.length
    assert_equal @gym_haters_text.text, documents.first.text
    assert_equal @my_bio.text, documents.last.text
  end

  # # It's your duty create the lasts two tests
  def test_ignoring_accent
  end


  def test_stemming
  end

end