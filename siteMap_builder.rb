require 'nokogiri'
require 'open-uri'
require 'set'
require 'uri'
require 'builder'

class SiteMapGenerator
  attr_reader :start_url, :max_depth, :urls

  def initialize(start_url, max_depth)
    @start_url = start_url
    @max_depth = max_depth
    @visited = Set.new
    @to_visit = [[start_url, 0]]
    @urls = []
  end

  def fetch_page(url)
    begin
      options = {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
      Nokogiri::HTML(URI.open(url, options))
    rescue => e
      puts "Failed to fetch page: #{url}, Error: #{e}"
      nil
    end
  end

  def extract_links(page, base_url)
    links = []
    return links if page.nil?

    page.css('a[href]').each do |link|
      href = link['href']
      next if href.nil? || href.empty?

      begin
        uri = URI.join(base_url, href).to_s
        links << uri if same_domain?(base_url, uri)
      rescue URI::InvalidURIError => e
        puts "Invalid URI: #{href}, Error: #{e}"
      end
    end

    puts "Extracted links from #{base_url}: #{links}"
    links.uniq
  end

  def same_domain?(base, link)
    base_host = URI(base).host
    link_host = URI(link).host
    base_host == link_host
  end

  def build_sitemap
    until @to_visit.empty?
      url, depth = @to_visit.shift
      next if @visited.include?(url)
      break if depth > @max_depth

      @visited.add(url)
      @urls << url
      puts "Visiting: #{url}"
      page = fetch_page(url)
      links = extract_links(page, @start_url)

      links.each do |link|
        @to_visit << [link, depth + 1] unless @visited.include?(link) || @to_visit.any? { |u, d| u == link }
      end
    end
    @urls
  end

  def generate_sitemap_xml
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
    xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
      @urls.each do |url|
        xml.url do
          xml.loc url
        end
      end
    end
    xml.target!
  end
end

if ARGV.length != 2
  puts "Usage: ruby site_map.rb <start_url> <max_depth>"
  exit
end

start_url = ARGV[0]
max_depth = ARGV[1].to_i

generator = SiteMapGenerator.new(start_url, max_depth)
generator.build_sitemap
sitemap_xml = generator.generate_sitemap_xml

puts sitemap_xml
