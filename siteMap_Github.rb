require 'octokit'
require 'builder'

def fetch_repository_contents(owner, repo)
  client = Octokit::Client.new
  contents = client.contents("#{owner}/#{repo}")

  contents.map { |content| content[:type] == 'dir' ? fetch_directory_contents(owner, repo, content[:path]) : content[:html_url] }
end

def fetch_directory_contents(owner, repo, path)
  client = Octokit::Client.new
  contents = client.contents("#{owner}/#{repo}", path: path)

  contents.map { |content| content[:type] == 'dir' ? fetch_directory_contents(owner, repo, content[:path]) : content[:html_url] }
end

def generate_sitemap(owner, repo)
  urls = fetch_repository_contents(owner, repo)

  xml = Builder::XmlMarkup.new(indent: 2)
  xml.instruct! :xml, version: '1.0', encoding: 'UTF-8'

  xml.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
    urls.flatten.each do |url|
      xml.url do
        xml.loc url
      end
    end
  end

  puts xml.target!
end

if ARGV.length < 2
  puts "Usage: ruby github_sitemap_builder.rb <owner> <repo>"
  exit
end

owner = ARGV[0]
repo = ARGV[1]

generate_sitemap(owner, repo)

