Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Open source iOS/macOS/tvOS ORM, fast and agile designed to be simple and logical
  #	 to use.
  #

  s.name         = "SharkORM"
  s.version      = "2.1.1"
  s.summary      = "SQLite based ORM for iOS, tvOS & macOS"
  s.description  = <<-DESC
Shark is an open source ORM, designed from the start to be low maintenance and natural to use, developers choose shark for its power and simplicity.

With just a couple of lines of code getting you started, it is faster to get started than any other database system.

Real class objects are used and extended, with a simple persistence model and the datastore is always refactored to your class structures, with no effort from the developer.

Objects are retrieved using a FLUENT interface, but the same methods give you COUNT, SUM, GROUP & DISTINCT.

Your object model is tuneable with indexes and query optimisations and it is entirely thread-safe in every situation, in fact, you don't have to worry about it at all.
                   DESC

  s.homepage     = "http://sharkorm.com/"
  s.license      =  { :type => "MIT", :file => "LICENSE" }
  s.author             = { "Adrian Herridge" => "adrian@sharkorm.com" }
  s.social_media_url   = "http://twitter.com/editfmah"
  s.ios.deployment_target = "7.0"
  s.osx.deployment_target = "10.8"
  #s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/sharksync/sharkorm.git", :tag => "#{s.version}" }
  s.source_files  = "SharkORM/**/*.{h,m,c}"
  s.public_header_files = "SharkORM/Core/DBAccess.h", "SharkORM/Core/SharkORM.h"


end

