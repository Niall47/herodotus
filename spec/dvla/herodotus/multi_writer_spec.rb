require 'dvla/herodotus'

RSpec.describe DVLA::Herodotus::MultiWriter do
  it 'calls write on every registered writer when write is called' do
    writer_one = instance_double(File)
    writer_two = instance_double(File)

    argument_one = 'argument one'
    argument_two = 'argument two'

    expect(writer_one).to receive(:write).with(argument_one, argument_two)
    expect(writer_two).to receive(:write).with(argument_one, argument_two)

    multi_writer = DVLA::Herodotus::MultiWriter.new(writer_one, writer_two)
    multi_writer.write(argument_one, argument_two)
  end

  it 'calls close on every registered writer when close is called' do
    writer_one = instance_double(File)
    writer_two = instance_double(File)

    expect(writer_one).to receive(:close)
    expect(writer_two).to receive(:close)

    multi_writer = DVLA::Herodotus::MultiWriter.new(writer_one, writer_two)
    multi_writer.close
  end

  it 'does not close the standard output when close is called' do
    multi_writer = DVLA::Herodotus::MultiWriter.new($stdout)
    multi_writer.close

    expect($stdout.closed?).to be false
  end

  it 'strips colours from messages when writing to non-stdout targets' do
    file_output = StringIO.new
    coloured_message = 'Test String'.red.underline.bg_blue

    allow($stdout).to receive(:write)

    multi_writer = DVLA::Herodotus::MultiWriter.new($stdout, file_output)
    multi_writer.write(coloured_message)

    expect(file_output.string).to eq('Test String')
  end

  it 'keeps colours when strip_colours_from_files is false' do
    file_output = StringIO.new
    coloured_message = 'Test String'.red
    config = DVLA::Herodotus.config { |c| c.strip_colours_from_files = false }

    allow($stdout).to receive(:write)

    multi_writer = DVLA::Herodotus::MultiWriter.new($stdout, file_output, config: config)
    multi_writer.write(coloured_message)

    expect(file_output.string).to eq("\e[31mTest String\e[39m")
  end

  it 'strips colours when strip_colours_from_files is true' do
    file_output = StringIO.new
    coloured_message = 'Test String'.red
    config = DVLA::Herodotus.config { |c| c.strip_colours_from_files = true }

    allow($stdout).to receive(:write)

    multi_writer = DVLA::Herodotus::MultiWriter.new($stdout, file_output, config: config)
    multi_writer.write(coloured_message)

    expect(file_output.string).to eq('Test String')
  end

  it 'strips colours from both prefix and message when strip_colours_from_files is true' do
    file_output = StringIO.new
    config = DVLA::Herodotus.config do |c|
      c.strip_colours_from_files = true
      c.prefix_colour = 'blue.bold'
    end

    allow($stdout).to receive(:write)

    multi_writer = DVLA::Herodotus::MultiWriter.new($stdout, file_output, config: config)
    logger = DVLA::Herodotus::HerodotusLogger.new('TestSystem', multi_writer, config: config)
    logger.info 'Test String'.red

    expect(file_output.string).to match(/\[TestSystem \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [a-f0-9]{8}\] INFO -- : Test String\n/)
  end
end
