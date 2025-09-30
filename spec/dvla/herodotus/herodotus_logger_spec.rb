require 'dvla/herodotus'
require 'stringio'

RSpec.describe DVLA::Herodotus::HerodotusLogger do
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
  let(:logger) { DVLA::Herodotus.logger('rspec') }

  after(:each) do
    DVLA::Herodotus.main_logger = nil
  end

  [
    { method: :debug, string_value: 'DEBUG' },
    { method: :info, string_value: 'INFO' },
    { method: :warn, string_value: 'WARN' },
    { method: :error, string_value: 'ERROR' },
    { method: :fatal, string_value: 'FATAL' },
  ].each do |testcase|
    it 'logs with the same correlation id when no scenario name is passed in' do
      allow(Time).to receive(:now).and_return(Time.new(2022))
      allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000', '00112233-4455-6677-8899-aabbccddeeff')

      expect { logger.send(testcase[:method], 'First Log') }.to output("[rspec 2022-01-01 00:00:00 123e4567] #{testcase[:string_value]} -- : First Log\n")
                                          .to_stdout_from_any_process
      expect { logger.send(testcase[:method], 'Second Log') }.to output("[rspec 2022-01-01 00:00:00 123e4567] #{testcase[:string_value]} -- : Second Log\n")
                                               .to_stdout_from_any_process
    end


    it 'logs with the different correlation id when new_scenario is called' do
      allow(Time).to receive(:now).and_return(Time.new(2022))
      allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000', '00112233-4455-6677-8899-aabbccddeeff')

      expect { logger.send(testcase[:method], 'First Log') }.to output("[rspec 2022-01-01 00:00:00 123e4567] #{testcase[:string_value]} -- : First Log\n")
                                                                                 .to_stdout_from_any_process
      logger.new_scenario('scenario_id')
      expect { logger.send(testcase[:method], 'Second Log') }.to output("[rspec 2022-01-01 00:00:00 00112233] #{testcase[:string_value]} -- : Second Log\n")
                                                                                   .to_stdout_from_any_process
    end

    it 'logs a block that is passed in' do
      allow(Time).to receive(:now).and_return(Time.new(2022))
      allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000', '00112233-4455-6677-8899-aabbccddeeff')

      expect { logger.send(testcase[:method]) { 'Test Log' } }
        .to output("[rspec 2022-01-01 00:00:00 123e4567] #{testcase[:string_value]} -- : Test Log\n").to_stdout_from_any_process
    end

    it 'updates all ProcWriters within a MultiWriter with the current scenario' do
      expected_scenario_name = 'Expected Scenario'

      proc_writer_double = instance_double(DVLA::Herodotus::ProcWriter)
      targets_double = instance_double(Array)
      expect(proc_writer_double).to receive(:scenario=).with(expected_scenario_name)
      allow(proc_writer_double).to receive(:instance_of?).with(DVLA::Herodotus::ProcWriter).and_return(true)
      allow(targets_double).to receive(:any?).with(DVLA::Herodotus::ProcWriter).and_return(true)
      allow(targets_double).to receive(:select).and_return([proc_writer_double])

      multi_writer_double = instance_double(DVLA::Herodotus::MultiWriter)
      allow(multi_writer_double).to receive(:write)
      allow(multi_writer_double).to receive(:targets).and_return(targets_double)
      allow(multi_writer_double).to receive(:respond_to?).with(:write).and_return(true)
      allow(multi_writer_double).to receive(:respond_to?).with(:close).and_return(true)
      allow(multi_writer_double).to receive(:respond_to?).with(:path).and_return(false)
      allow(multi_writer_double).to receive(:is_a?).with(DVLA::Herodotus::MultiWriter).and_return(true)

      logger = DVLA::Herodotus::HerodotusLogger.new('rspec', multi_writer_double)
      logger.new_scenario(expected_scenario_name)

      logger.send(testcase[:method], 'Test log')
    end
  end

  it 'starts a new scenario with the non-default correlation id every time new_scenario is called' do
    allow(Time).to receive(:now).and_return(Time.new(2022))
    allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000', '00112233-4455-6677-8899-aabbccddeeff', 'e19f77a7-337c-47a8-93a9-c2180040ba03')

    logger.new_scenario('name of the new scenario')
    expect { logger.info('Test Log') }.to output("[rspec 2022-01-01 00:00:00 00112233] INFO -- : Test Log\n")
                                                                .to_stdout_from_any_process

    logger.new_scenario('name of another new scenario')
    expect { logger.info('Test Log') }.to output("[rspec 2022-01-01 00:00:00 e19f77a7] INFO -- : Test Log\n")
                                            .to_stdout_from_any_process
  end

  it 'overrides the correlation ids of other loggers when logger instantiated with \'main\' is called' do
    other_logger = DVLA::Herodotus.logger('main-rspec', config: DVLA::Herodotus.config { |c| c.main = true })
    expect(logger.correlation_id).to eq(other_logger.correlation_id)
  end

  it 'does not override the system name of other loggers when merge_correlation_ids is called' do
    other_logger = DVLA::Herodotus.logger('main-rspec', config: DVLA::Herodotus.config { |c| c.main = true })
    expect(logger.system_name).not_to eq(other_logger.system_name)
  end

  it 'should override the main logger when another instance initialized with main' do
    other_logger1 = DVLA::Herodotus.logger('main-rspec', config: DVLA::Herodotus.config { |c| c.main = true })
    expect(DVLA::Herodotus.main_logger).to eq(other_logger1)

    other_logger2 = DVLA::Herodotus.logger('main-main-rspec', config: DVLA::Herodotus.config { |c| c.main = true })
    expect(DVLA::Herodotus.main_logger).to eq(other_logger2)

    expect(logger.correlation_id).to eq(other_logger2.correlation_id)
    expect(other_logger1.correlation_id).to eq(other_logger2.correlation_id)
  end

  context '#new_scenario' do
    it 'should not override the correlation_id of other loggers if main_logger not set' do
      logger1_correlation_id = logger.correlation_id

      logger2 = DVLA::Herodotus.logger('other-rspec')
      logger2.new_scenario('blah')

      expect(logger.correlation_id).to eq(logger1_correlation_id)
    end

    it 'should override the correlation_id of other loggers if main_logger is set' do
      logger1_correlation_id = logger.correlation_id

      logger2 = DVLA::Herodotus.logger('logger-2', config: DVLA::Herodotus.config { |c| c.main = true })
      logger2.new_scenario('blah')

      expect(logger.correlation_id).not_to eq(logger1_correlation_id)
      expect(logger.correlation_id).to eq(logger2.correlation_id)
    end

    it 'should override the correlation_id of all loggers if new_scenario called on logger that is not main' do
      logger1_correlation_id = logger.correlation_id

      logger2 = DVLA::Herodotus.logger('logger-2', config: DVLA::Herodotus.config { |c| c.main = true })
      logger.new_scenario('blah')

      expect(logger.correlation_id).not_to eq(logger1_correlation_id)
      expect(logger.correlation_id).to eq(logger2.correlation_id)
    end

    it 'should set the scenario_id' do
      logger.new_scenario('blah')
      expect(logger.scenario_id).to eq('blah')
    end

    it 'should only set the scenario_id of the logger that called the method when main not set' do
      logger2 = DVLA::Herodotus.logger('logger-2')
      logger2.new_scenario('blah')

      expect(logger.scenario_id).to be_nil
      expect(logger2.scenario_id).to eq('blah')
    end

    it 'should set the scenario_id of all loggers when main is set' do
      logger2 = DVLA::Herodotus.logger('logger-2', config: DVLA::Herodotus.config { |c| c.main = true })
      logger2.new_scenario('blah')

      expect(logger.scenario_id).to eq('blah')
      expect(logger2.scenario_id).to eq('blah')
    end
  end

  context 'buffered logging' do
    [
      { method: :debug, string_value: 'DEBUG' },
      { method: :info, string_value: 'INFO' },
      { method: :warn, string_value: 'WARN' },
      { method: :error, string_value: 'ERROR' },
      { method: :fatal, string_value: 'FATAL' },
    ].each do |testcase|
      it "buffers #{testcase[:method]} logs when buffered: true" do
        allow(Time).to receive(:now).and_return(Time.new(2022))
        allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000')

        expect { logger.send(testcase[:method], 'Buffered Log', buffered: true) }
          .not_to output.to_stdout_from_any_process
      end

      it "outputs #{testcase[:method]} logs immediately when buffered: false" do
        allow(Time).to receive(:now).and_return(Time.new(2022))
        allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000')

        expect { logger.send(testcase[:method], 'Immediate Log', buffered: false) }
          .to output("[rspec 2022-01-01 00:00:00 123e4567] #{testcase[:string_value]} -- : Immediate Log\n")
          .to_stdout_from_any_process
      end

      it "outputs #{testcase[:method]} logs immediately by default" do
        allow(Time).to receive(:now).and_return(Time.new(2022))
        allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000')

        expect { logger.send(testcase[:method], 'Default Log') }
          .to output("[rspec 2022-01-01 00:00:00 123e4567] #{testcase[:string_value]} -- : Default Log\n")
          .to_stdout_from_any_process
      end
    end

    it 'releases all buffered logs in order when release_buffered_logs is called' do
      allow(Time).to receive(:now).and_return(Time.new(2022))
      allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000')

      output = capture_stdout do
        logger.info('First buffered', buffered: true)
        logger.warn('Not buffered')
        logger.error('Second buffered', buffered: true)
        logger.release_buffered_logs
      end

      expected_lines = [
        "[rspec 2022-01-01 00:00:00 123e4567] WARN -- : Not buffered",
        "[rspec 2022-01-01 00:00:00 123e4567] INFO -- : First buffered",
        "[rspec 2022-01-01 00:00:00 123e4567] ERROR -- : Second buffered"
      ]

      expect(output.strip.split("\n")).to eq(expected_lines)
    end

    it 'clears buffered logs after releasing them' do
      logger.info('Buffered log', buffered: true)
      logger.release_buffered_logs

      expect { logger.release_buffered_logs }.not_to output.to_stdout_from_any_process
    end

    it 'handles blocks in buffered logs' do
      allow(Time).to receive(:now).and_return(Time.new(2022))
      allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000')

      logger.info(buffered: true) { 'Block message' }

      expect { logger.release_buffered_logs }
        .to output("[rspec 2022-01-01 00:00:00 123e4567] INFO -- : Block message\n")
        .to_stdout_from_any_process
    end

    it 'mixes buffered and immediate logs correctly' do
      allow(Time).to receive(:now).and_return(Time.new(2022))
      allow(SecureRandom).to receive(:uuid).and_return('123e4567-e89b-12d3-a456-426614174000')

      expect { logger.info('Immediate 1') }
        .to output("[rspec 2022-01-01 00:00:00 123e4567] INFO -- : Immediate 1\n")
        .to_stdout_from_any_process

      logger.info('Buffered 1', buffered: true)
      logger.info('Buffered 2', buffered: true)

      expect { logger.info('Immediate 2') }
        .to output("[rspec 2022-01-01 00:00:00 123e4567] INFO -- : Immediate 2\n")
        .to_stdout_from_any_process

      expected_buffered = "[rspec 2022-01-01 00:00:00 123e4567] INFO -- : Buffered 1\n" +
                         "[rspec 2022-01-01 00:00:00 123e4567] INFO -- : Buffered 2\n"

      expect { logger.release_buffered_logs }.to output(expected_buffered).to_stdout_from_any_process
    end
  end
end
