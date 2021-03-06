require 'open-uri'
require 'nokogiri'

class Scraping < ActiveRecord::Base
  has_many :boards

  # スクレイピングを実行します
  def self.invoke(limit=10)
    all.each do |task|
      task.execute! limit
    end
  end

  # スクレイピング処理をここに実装
  def execute!(limit)
    # charset取得
    charset = URI.parse(self.url).read.charset
    # 一覧取得
    index = Nokogiri::HTML.parse(open(self.url).read, nil)

    index.css('a').each_with_index do |anchor, i|
      sid = anchor[:href].sub('\/l50','')
      target_uri = %(#{absolute_url}/#{sid})

      board_elem = Nokogiri::HTML.parse(open(target_uri).read)

      board = Board.find_by(sid: sid) || Board.factory(self.id, sid, board_elem)
      board.save! if board.new_record?

      cursor = board.comments.count

      board_elem.css('//dl[@class="thread"]').each do |thread|
        res_headers = thread.css("dt")
        res_bodies = thread.css("dd")
 
        res_headers.each_with_index do |res_head, j|
          next if j < cursor
          comment = Comment.factory board, res_headers[j], res_bodies[j]
          comment.save!
        end
      end

      break if limit && i > limit 
    end
  end

  # urlから絶対URLを取得します
  def absolute_url
    self.url.gsub(/news4vip\/subback.html/, "test/read.cgi/news4vip")
    #"http://hayabusa.2ch.net/test/read.cgi/news4vip"
  end
end
