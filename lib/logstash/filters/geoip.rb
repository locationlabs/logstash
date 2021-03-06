require "logstash/filters/base"
require "logstash/namespace"
require "tempfile"

# Add GeoIP fields from Maxmind database
#
# GeoIP filter, adds information about geographical location of IP addresses.
# This filter uses Maxmind GeoIP databases, have a look at
# https://www.maxmind.com/app/geolite
#
# Logstash releases ship with the GeoLiteCity database made available from
# Maxmind with a CCA-ShareAlike 3.0 license. For more details on geolite, see
# <http://www.maxmind.com/en/geolite>.
class LogStash::Filters::GeoIP < LogStash::Filters::Base
  config_name "geoip"
  plugin_status "experimental"

  # GeoIP database file to use, Country, City, ASN, ISP and organization
  # databases are supported
  #
  # If not specified, this will default to the GeoLiteCity database that ships
  # with logstash.
  config :database, :validate => :path

  # The field containing IP address, hostname is also OK. If this field is an
  # array, only the first value will be used.
  config :field, :validate => :string, :deprecated => true

  # The field containing IP address, hostname is also OK. If this field is an
  # array, only the first value will be used.
  config :source, :validate => :string

  # Array of fields that we want to be included in our event
  # Default it will include all fields.
  # Possible fields depend on the database type
  # For the built in GeoLiteCity database:
  # city_name, continent_code, country_code2, country_code3, country_name, dma_code, ip, latitude, longitude, postal_code, region_name, timezone
  config :fields, :validate => :array

  public
  def register
    require "geoip"
    if @database.nil?
      if __FILE__ =~ /^file:\/.+!.+/
        begin
          # Running from a jar, assume GeoLiteCity.dat is at the root.
          jar_path = [__FILE__.split("!").first, "/GeoLiteCity.dat"].join("!")
          tmp_file = Tempfile.new('logstash-geoip')
          tmp_file.write(File.read(jar_path))
          tmp_file.close # this file is reaped when ruby exits
          @database = tmp_file.path
        rescue => ex
          raise "Failed to cache, due to: #{ex}\n#{ex.backtrace}"
        end
      else
        if File.exists?("GeoLiteCity.dat")
          @database = "GeoLiteCity.dat"
        else
          raise "You must specify 'database => ...' in your geoip filter"
        end
      end
    end
    @logger.info("Using geoip database", :path => @database)
    @geoip = ::GeoIP.new(@database)

    @geoip_type = case @geoip.database_type
    when GeoIP::GEOIP_CITY_EDITION_REV0, GeoIP::GEOIP_CITY_EDITION_REV1
      :city
    when GeoIP::GEOIP_COUNTRY_EDITION
      :country
    when GeoIP::GEOIP_ASNUM_EDITION
      :asn
    when GeoIP::GEOIP_ISP_EDITION, GeoIP::GEOIP_ORG_EDITION
      :isp
    else
      raise RuntimeException.new "This GeoIP database is not currently supported"
    end

    #TODO(electrical): Remove this when removing the field variable
    if @field
      if @source
        logger.error("'field' and 'source' are the same setting, but 'field' is deprecated. Please use only 'source'")
      end
      @source = @field
    end

  end # def register

  public
  def filter(event)
    return unless filter?(event)
    geo_data = nil
    begin
      ip = event[@source]
      ip = ip.first if ip.is_a? Array
      geo_data = @geoip.send(@geoip_type, ip)
    rescue SocketError => e
      @logger.error("IP Field contained invalid IP address or hostname", :field => @field, :event => event)
    rescue Exception => e
      @logger.error("Uknown error while looking up GeoIP data", :exception => e, :field => @field, :event => event)
    end
    unless geo_data.nil?
      geo_data_hash = geo_data.to_hash
      geo_data_hash.delete(:request)
      event["geoip"] = {} if event["geoip"].nil?
      geo_data_hash.each do |key, value|
        # Check if we have an array for specific fields
        if !fields.empty?
          # Check if the key is in our fields array
          if fields.include?(key.to_s)
            # convert key to string (normally a Symbol)
            event["geoip"][key.to_s] = value
          end
        else
          # convert key to string (normally a Symbol)
          event["geoip"][key.to_s] = value
        end
      end
      filter_matched(event)
    end
  end # def filter
end # class LogStash::Filters::GeoIP
