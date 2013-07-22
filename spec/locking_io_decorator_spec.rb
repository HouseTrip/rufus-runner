require 'spec_helper'

describe 'stdout' do

  it 'should be a locking io' do
    $stdout.should be_a(Rufus::LockingIODecorator)
  end

end


describe Rufus::LockingIODecorator do

  let(:io) { double('io') }

  subject { described_class.new(io) }

  %w(write puts print).each do |method|

    describe "##{method}" do

      it 'is wrapped in a Guard#sync call' do
        described_class::Guard.any_instance.should_receive(:sync).and_yield
        io.should_receive(method)
        subject.send(method)
      end

    end

  end

end


describe Rufus::LockingIODecorator::Guard do

  describe '#sync' do

    let(:lock_file) { double('lock_file', :flock => true) }

    before do
      subject.stub :lock_file => lock_file
    end

    it 'locks and unlocks a lock file' do
      subject.stub(:lock_file => lock_file)
      reached = false
      lock_file.should_receive(:flock).with(File::LOCK_EX)
      subject.sync do
        reached = true
        lock_file.should_receive(:flock).with(File::LOCK_UN)
      end
      reached.should be_true
    end

    it 'releases locks on errors' do
      lock_file.should_receive(:flock).with(File::LOCK_UN)
      lambda do
        subject.sync do
          raise "error"
        end
      end.should raise_error
    end

  end

  describe '#lock_file' do

    it 'uses a unique lock file handle per thread' do
      thread = Thread.new { subject.send(:lock_file) }
      thread.value.should_not == subject.send(:lock_file)
    end

    it 'uses a unique lock file handle per process' do
      subject
      object_id = get_from_other_process do |pipe|
        fork do
          pipe.return(subject.send(:lock_file).object_id)
        end
      end
      subject.send(:lock_file).object_id.should_not == object_id
    end

    it 'users a shared lock file across child processes' do
      subject
      path = get_from_other_process do |pipe|
        fork do
          pipe.return(subject.send(:lock_file).path)
        end
      end
      subject.send(:lock_file).path.should == path
    end
  end

end
