module ApplicationHelper
  def strip_rails_root(dir)
    ret = dir.gsub(Rails.root.to_s, "")
    ret = ret[1 .. -1] if ret =~ Regexp.new("^/")
    ret
  end

  def build_duration(build)
    seconds = (build.finished_at - build.started_at).to_i
    minutes = seconds / 60
    seconds = seconds - minutes * 60
    if minutes == 0
      "%ds" % [seconds]
    else
      "%dm %ds" % [minutes, seconds]
    end
  end

  def format_stability(stability)
    return "not yet built" if stability.nil?
    case stability
    when -1
      "not enough data"
    when 0
      "abandon the project"
    when 1
      "start fixing asap"
    when 2
      "could be worse"
    when 3
      "not bad"
    when 4
      "looking good"
    when 5
      "great"
    end
  end
end
