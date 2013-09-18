require 'hiera/config'


class Hiera
  module Backend
    class Ldapjson_backend

      def initialize(cache=nil)
        require 'json'
        require 'net/ldap'

        Hiera.debug("Hiera LdapJson backend starting")
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        Hiera.debug("Looking up #{key} in LdapJson backend")

        ldap_host = Config[:ldapjson][:ldap_host]
        Hiera.debug("Found config: ldap_host=#{ldap_host}")
        ldap_port = Config[:ldapjson][:ldap_port]
        Hiera.debug("Found config: ldap_host=#{ldap_port}")
        ldap_base = Config[:ldapjson][:ldap_base]
        Hiera.debug("Found config: ldap_base=#{ldap_base}")
        ldap_bind_dn = Config[:ldapjson][:ldap_bind_dn]
        Hiera.debug("Found config: ldap_bind_dn=#{ldap_bind_dn}")
        ldap_bind_password = Config[:ldapjson][:ldap_bind_password]
        Hiera.debug("Found config: ldap_bind_password=******")
        hiera_base_ou = Config[:ldapjson][:hiera_base_ou]
        Hiera.debug("Found config: hiera_base_ou=#{hiera_base_ou}")
        ldap_attr = Config[:ldapjson][:ldap_attr]
        Hiera.debug("Found config: ldap_attr=#{ldap_attr}")

        auth = {
          :method => :simple,
          :username => ldap_bind_dn,
          :password => ldap_bind_password
        }

        Net::LDAP.open(:host => ldap_host,
                       :port => ldap_port,
                       :auth => auth) do |conn|
          Backend.datasources(scope, order_override) do |source|
            Hiera.debug("Looking for data source #{source}")
            # the ldap filter is constructed from
            #
            # cn=hello.example.com,ou=instances,ou=hiera,     dc=example,dc=com
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^|^^^^^^^^^^^^^|^^^^^^^^^^^^^^^^^
            #     the "/" separated source      hiera_base_ou     ldap_base
            #
            # for the moment we're not performing interpolation on any
            # of the non-source fields, though we could in the future
            # if we decided that was funky.
            search_base = [source_to_ldap_fragment(source),
                           hiera_base_ou,
                           ldap_base].join(",")

            conn.search(:base => search_base,
                        :scope => Net::LDAP::SearchScope_BaseObject,
                        :attributes => ldap_attr) do |entry|
              Hiera.debug("Processing search entry...")

              attrs = entry[ldap_attr]
              if attrs.nil? or attrs.empty?
                Hiera.debug("Couldn't find attr, skipping.")
                next
              end

              if attrs.length > 1
                raise Exception, "LdapJson doesn't support duplicated attrs"
              end

              json_data = attrs[0]

              if json_data.nil? or json_data.empty?
                Hiera.debug("No json data in attr, skipping.")
                next
              end

              data = JSON.parse(json_data)
              if data.empty? or not data.include?(key)
                Hiera.debug("Json data didn't contain key, skipping.")
                next
              end

              new_answer = Backend.parse_answer(data[key], scope)
              case resolution_type
              when :array
                unless new_answer.kind_of? Array or new_answer.kind_of? String
                  ex = "Expected Array and got #{new_answer.class}"
                  raise Exception, ex
                end
                answer ||= []
                Hiera.debug("Merging new answer to array.")
                answer << new_answer
              when :hash
                raise Exception, "hash is not supported"
              else
                # priority search...return after first item.
                Hiera.debug("Found answer, breaking.")
                answer = new_answer
                break
              end # case
            end # search
          end # data sources
        end # open

        return answer

      end # def lookup

      def source_to_ldap_fragment(source)
        # source is a "/" separated string.  we turn all non-final
        # fragments into ou's, and the final into cn, e.g.:
        #
        # "hello" => "cn=hello"
        #
        # "hello/there" => "cn=there,ou=hello"
        #
        # "hello/there/bob" => "cn=bob,ou=there,ou=hello"
        #
        segments = source.split("/").reverse()
        cn = "cn=#{segments[0]}"

        if segments.length == 1
          cn
        else
          [cn,
           segments[1, segments.length].collect {|s| "ou=#{s}"}].join(",")
        end
      end # def source_to_ldap_fragment

    end # class Ldapjson_backend
  end # module Backend
end # class Hiera
