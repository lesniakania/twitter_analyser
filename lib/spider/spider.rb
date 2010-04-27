require 'rubygems'
require 'net/http'
require 'nokogiri'
require 'schema'
require 'user'
require 'twitt'
require 'user_follower'
require 'follower'
require 'timeout'

class Spider
  attr_accessor :base_url, :visited, :queue, :root_username, :limit

  def initialize(root_username,limit)
    @base_url = "http://www.twitter.com"
    @visited = []
    @queue = [Follower.new(nil,root_username)]
    @root_username = root_username
    @limit = limit
  end

	def self.visit(url)
		response = visit_without_redirecting(url)
    response_body = response.body
    doc = Nokogiri::HTML(response_body)
    if response.code.to_s =~ /301|302/
      redirect_url = doc.xpath('//a').first.get_attribute('href')
      response_body = visit_without_redirecting(redirect_url).body
    end
    response_body
	end

  def self.visit_without_redirecting(url)
    Net::HTTP.get_response(URI.parse(url))
  end

  def scan_twitter(level=1)
    sleep(3)
    return if queue.empty? or (limit > 0 and level > limit)
        
    follower = queue.shift
    p username = follower.follower_nick

    url = "#{base_url}/#{username}"
    doc = Spider.get_doc(url)

    name = doc.xpath('//span[@class="fn"]').text
    location = doc.xpath('//span[@class="adr"]').text
    if user = User.find(:nick => username)
      user.update(:name => name, :location => location)
    else
      user = User.create(:nick => username, :name => name, :location => location)
    end

    if visited_user = User.find(:nick => follower.user_nick) and not UserFollower.find(:user_id => visited_user.id, :follower_id => user.id)
      UserFollower.create(:user_id => visited_user.id, :follower_id => user.id)
    end

    visited << username
    
    get_twitts(user,doc)

    @queue += get_followers(username,doc)
    
    scan_twitter(level+1)
  end

  def self.get_doc(url)
    body = nil
    while (body == nil)
      begin
        body = Spider.visit(url)
      rescue Timeout::Error
        puts "Connection reset. Waiting..."
        sleep(5*60)
      rescue Errno::ECONNRESET
        puts "Connection reset. Waiting..."
        sleep(2*60)
      rescue
        puts "Unknown exception. Waiting..."
        sleep(5*60)
      end
    end
    Nokogiri::HTML(body)
  end

  def get_twitts(user,doc)
    doc.xpath('//li[regex(.,"class","status")]', RegexpComparator.new).each do |li|
      id,body,date,parent_id,parent_url,parent_username = get_twitt(li)

      parent_result = false
      if parent_id
        parent_result = get_parent_twitt(parent_username,Spider.get_doc(parent_url))
      end
      
      unless parent_result
        parent_id = nil
      end
      if Twitt.find(:id => id) == nil
        Twitt.create(:id => id, :parent_id => parent_id, :date => date, :body => body, :user_id => user.id)
      end
    end
  end

  def get_parent_twitt(username,doc)
    result = false
    doc.xpath('//div[regex(.,"id","status")]', RegexpComparator.new).each do |div|
      id,body,date,parent_id,parent_url,parent_username = get_twitt(div)

      parent_result = false
      if parent_id
        parent_result = get_parent_twitt(parent_username,Spider.get_doc(parent_url))
      end

      unless user = User.find(:nick => username)
        user = User.create(:nick => username, :name => nil, :location => nil)
      end

      unless parent_result
        parent_id = nil
      end
      if Twitt.find(:id => id) == nil
        Twitt.create(:id => id, :parent_id => parent_id, :date => date, :body => body, :user_id => user.id)
      end
      result = true
    end
    
    result
  end

  def get_twitt(div)
    id = div.get_attribute("id").match(/\d+/).to_s
    body = div.children.xpath('./span[@class="entry-content"]').text

    meta = div.children.xpath('./span[@class="meta entry-meta"]')
    date = DateTime.parse(meta.children.xpath('./span[@class="published timestamp"]').first.get_attribute("data").match(/'.*'/).to_s.delete("'"))
    parent_id = nil
    parent_url = nil
    parent_username = nil
    meta.xpath('./a').each do |a|
      parent_url = a.get_attribute("href")
      splitted = parent_url.split("/")
      parent_id = splitted.last if a.text.to_s =~ /reply/
      parent_username = splitted[-3]
    end
    [id,body,date,parent_id,parent_url,parent_username]
  end

  def get_followers(username,doc)
    followers = []
    doc.xpath('//a[@rel="contact"]').each do |user|
      follower_nick = user.get_attribute('href')[1..-1]
      followers << Follower.new(username,follower_nick)
    end

    followers.each do |follower|
      followers.delete(follower) if visited.include?(follower) or queue.include?(follower)
    end

    followers
  end
end

class RegexpComparator
  def regex node_set, attribute, pattern
    node_set.find_all { |node| node[attribute] =~ /#{pattern}/ }
  end
end

#Spider.new("Dziamka",-1).scan_twitter()