require 'redis'

class Person

  attr_accessor :id, :email

  def initialize(email, redis = Redis.current)
    @email = email
    @redis = redis
  end

  def save
    @id = @redis.incr "persons::uids"

    #Give an id to the email and create an index to be searched by ID
    @redis.set "person:#{@id}", @email
  end

end

class SimpleSearch

  def initialize(redis = Redis.current)
    @redis = redis
  end

  def search(word)
    # results = []
    # email_ids = @redis.smembers word

    # email_ids.each do |id|
    #   results << (@redis.get "person:#{id}")
    # end
    # results

    #ALPHA ordenar por string
    @redis.sort word, {:by => "person:*", :order => "ALPHA asc", :get => "person:*"}
  end

  def index(*persons)
    persons.each do |person|
      prefix_aux = ""
      email = person.email

      #Create prefix indexes with id's on the set
      (email[0..email.index("@") - 1]).each_char do |c|
        prefix_aux << c
        @redis.sadd "#{prefix_aux}", person.id
      end
    end
  end
end

joao = Person.new("joao@mail.com")
joao.save

joao_nunes = Person.new("joao_nunes@mail.com")
joao_nunes.save

quim = Person.new("quim@mail.com")
quim.save

simple_search = SimpleSearch.new
simple_search.index(joao, joao_nunes, quim)

puts simple_search.search("j")
