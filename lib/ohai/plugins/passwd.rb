
Ohai.plugin(:Passwd) do
  provides "etc", "current_user"
  optional true

  # @param [String] str
  #
  # @return [String]
  #
  def fix_encoding(str)
    str.force_encoding(Encoding.default_external) if str.respond_to?(:force_encoding)
    str
  end

  def powershell_out(ps)
    Mixlib::ShellOut.new("powershell.exe", "-c", ps).run_command
  end

  collect_data do
    require "etc" unless defined?(Etc)

    unless etc
      etc Mash.new

      etc[:passwd] = Mash.new
      etc[:group] = Mash.new

      Etc.passwd do |entry|
        user_passwd_entry = Mash.new(dir: entry.dir, gid: entry.gid, uid: entry.uid, shell: entry.shell, gecos: entry.gecos)
        user_passwd_entry.each_value { |v| fix_encoding(v) }
        entry_name = fix_encoding(entry.name)
        etc[:passwd][entry_name] = user_passwd_entry unless etc[:passwd].key?(entry_name)
      end

      Etc.group do |entry|
        group_entry = Mash.new(gid: entry.gid,
                               members: entry.mem.map { |u| fix_encoding(u) })

        etc[:group][fix_encoding(entry.name)] = group_entry
      end
    end

    unless current_user
      current_user fix_encoding(Etc.getpwuid(Process.euid).name)
    end
  end

  collect_data(:windows) do
    unless etc
      etc Mash.new

      etc[:passwd] = Mash.new
      s = powershell_out("get-localuser | convertto-json")
      users = JSON.parse(s.stdout)
      users.each do |user|
        uname = user["Name"].strip.downcase
        Ohai::Log.debug("processing user #{uname}")
        etc[:passwd][uname] = Mash.new
        user.each do |key, val|
          etc[:passwd][uname][key.downcase] = val
        end
      end

      etc[:group] = Mash.new
      s = powershell_out("get-localgroup | convertto-json")
      groups = JSON.parse(s.stdout)
      groups.each do |group|
        gname = group["Name"].strip.downcase
        Ohai::Log.debug("processing group #{gname}")
        etc[:group][gname] = Mash.new
        group.each do |key, val|
          etc[:group][gname][key.downcase] = val
        end
        # calling this for each group is slow, but it requires
        # a specific group, soooooo....
        g = powershell_out(
          "get-localgroupmember -name '#{gname}' | convertto-json"
        )
        out = g.stdout
        if !out.empty?
          gmem = JSON.parse(g.stdout)
          etc[:group][gname]["members"] = gmem
        else
          etc[:group][gname]["members"] = []
        end
      end
    end
  end
end
