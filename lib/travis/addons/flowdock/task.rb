# encoding: UTF-8

module Travis
  module Addons
    module Flowdock
      # Publishes a build notification to flowdock rooms as defined in the
      # configuration (`.travis.yml`).
      #
      # Flowdock credentials are encrypted using the repository's ssl key.
      class Task < Travis::Task
        TEMPLATE = <<-str.gsub(/^\s*/m, '')
          <ul>
          <li><code><a href="https://github.com/%{slug}">%{slug}</a></code> build #%{number} has %{result}!</li>
          <li>Branch: <code>%{branch}</code></li>
          <li>Latest commit: <code><a href="%{sha_url}">%{sha}</a></code> by <a href="mailto:%{author_email}">%{author}</a></li>
          <li>Change view: %{compare_url}</li>
          <li>Build details: %{build_url}</li>
          </ul>
        str

        def targets
          params[:targets]
        end

        def message
          @message ||= begin
            args = {
              :slug   => repository[:slug],
              :number => build[:number],
              :branch => commit[:branch],
              :sha    => commit[:sha][0..6],
              :sha_url => "https://github.com/#{repository[:slug]}/commit/#{commit[:sha]}",
              :author => commit[:author_name],
              :author_email => commit[:author_email],
              :result => build_result,
              :compare_url => commit[:compare_url],
              :build_url => build_url
            }
            TEMPLATE % args
          end
        end

        private

          def process(timeout)
            targets.each { |target| send_message(target) }
          end

          def send_message(target)
            http.post(team_inbox_url_for(target)) do |r|
              r.body = MultiJson.encode(flowdock_payload)
              r.headers['Content-Type'] = 'application/json'
            end
          rescue URI::InvalidURIError => e
            error "Invalid Flowdock URL for #{repository[:slug]}##{build[:id]}: #{e.message}"
          end

          def build_url
            "#{Travis.config.http_host}/#{repository[:slug]}/builds/#{build[:id]}"
          end

          def build_result
            build[:state]
          end

          def build_tag
            {
              'passed' => 'ok',
              'failed' => 'fail',
              'errored' => 'error'
            }.fetch(build[:state], 'fail')
          end

          def team_inbox_url_for(target)
            "https://api.flowdock.com/v1/messages/team_inbox/#{target}"
          end

          def flowdock_subject
            "#{repository[:slug]} build ##{build[:number]} has #{build_result}!"
          end

          def flowdock_payload
            {
              source:       'Travis',
              from_address: "build+#{build_tag}@flowdock.com",
              subject:      flowdock_subject,
              content:      message,
              from_name:    'CI',
              project:      'Build Status',
              format:       'html',
              tags:         ["ci", build_tag],
              link:         build_url
            }
          end
      end
    end
  end
end

