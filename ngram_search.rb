require 'redis'
require 'set'

class NgramIndex

  def initialize(gram = 3, redis = Redis.current)
    @redis = redis
    @gram  = gram
  end

  def search(word)
    results = []

    grams = gramanizer(word)

    grams.each do |gram|
      results.push @redis.smembers gram
    end

    Set.new(results.flatten).to_a
  end

  def index(word)
    if word.size <= @gram
      @redis.sadd word, word
    else
      grams = gramanizer(word)

      grams.each do |index|
        @redis.sadd index, word
      end
    end
  end

  def gramanizer(word)
    word = "##{word}#" if (@gram == 3)

    index   = 0
    indexes = []
    range   = @gram - 1

    until (index + @gram) > word.size do
      indexes.push word[index..(index + range)]
      index = index + 1
    end

    indexes
  end

end

#TODO
#Criar Word e persistir objecto, intersecção
#Colocar pessos pelo match de occorências no search


Redis.current.flushdb

indexer = NgramIndex.new(3)

indexer.index "testinho"
indexer.index "testemunho"
indexer.index "thiago"
indexer.index "tiago"
indexer.index "joao.almeida@gmail.com"
indexer.index "aulas"
indexer.index "testiculos"

puts "Searching gmail   #{indexer.search 'gmail'}"
puts "Searching testicu #{indexer.search 'testiculos'}"
puts "Searching aukas   #{indexer.search 'aukas'}"