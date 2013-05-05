require 'hiera/config'

class Hiera
  module Backend
    class Ldapjson_backend

      def initialize(cache=nil)
        require 'json'
        require 'ldap'

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
        ldap_filter = Config[:ldapjson][:ldap_filter]
        Hiera.debug("Found config: ldap_filter=#{ldap_filter}")
        ldap_attr = Config[:ldapjson][:ldap_attr]
        Hiera.debug("Found config: ldap_attr=#{ldap_attr}")

        ldap_filter = Backend.parse_string(ldap_filter, scope, {"key" => key})
        Hiera.debug("After substitution, ldap_filter=#{ldap_filter}")

        conn = LDAP::Conn.new(ldap_host, ldap_port)
        conn.bind(ldap_bind_dn, ldap_bind_password) do |bound|
          Hiera.debug("Ldap bind successful")
          bound.search(ldap_base, LDAP::LDAP_SCOPE_SUBTREE, filter=ldap_filter,
                       attrs=[ldap_attr]) do |entry|
            Hiera.debug("Processing search entry...")
            attrs = entry[ldap_attr]
            if attrs.nil? or attrs.empty?
              Hiera.debug("Couldn't find attr, skipping.")
              next
            end
            for json_data in attrs
              if json_data.nil? or json_data.empty?
                Hiera.debug("No json data in attr, skipping.")
                next
              end
              data = JSON.parse(json_data)
              if data.empty? or not data.include?(key)
                Hiera.debug("Json data didn't contain key, skipping.")
                next
              end
              # for array resolution we just append to the array
              # whatever we find, we then goes onto the next attr
              # value / search results and keep adding to the array
              #
              # for priority searches we break after the first found
              # data item
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
                unless new_answer.kind_of? Hash
                  ex = "Expected Hash and got #{new_answer.class}"
                  raise Exception, ex
                end
                answer ||= {}
                Hiera.debug("Merging new answer to hash.")
                answer = Backend.merge_answer(new_answer,answer)
              else
                # priority search...break after first item.
                Hiera.debug("Found answer, breaking.")
                answer = new_answer
                break
              end
            end # for json_data in attrs

          end # bound.search

        end # conn.bind

        return answer

      end # def lookup

    end # class Ldapjson_backend
  end # module Backend
end # class Hiera
