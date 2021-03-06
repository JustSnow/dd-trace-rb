require 'ddtrace/ext/app_types'
require 'ddtrace/sync_writer'
require 'ddtrace/contrib/sidekiq/ext'
require 'resque'

module Datadog
  module Contrib
    module Resque
      # Uses Resque job hooks to create traces
      module ResqueJob
        def around_perform(*args)
          pin = Pin.get_from(::Resque)
          return yield unless pin && pin.tracer
          pin.tracer.trace(Ext::SPAN_JOB, service: pin.service) do |span|
            span.resource = name
            span.span_type = pin.app_type
            yield
            span.service = pin.service
          end
        ensure
          pin.tracer.shutdown! if pin && pin.tracer
        end
      end
    end
  end
end

Resque.after_fork do
  # get the current tracer
  pin = Datadog::Pin.get_from(Resque)
  next unless pin && pin.tracer
  # clean the state so no CoW happens
  pin.tracer.provider.context = nil
end
