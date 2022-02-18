# frozen_string_literal: true
#
# Author:: Nate Walck (<nate.walck@gmail.com>)
# Copyright:: Copyright (c) 2016-present Facebook, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Ohai.plugin(:Hardware) do
  provides "hardware"

  def system_profiler(datatype)
    sp_cmd = "system_profiler #{datatype} -json"
    # Hardware queries
    sp_std = shell_out(sp_cmd)
    JSON.parse(sp_std.stdout)[datatype]
  end

  collect_data(:darwin) do
    unless hardware
      hardware Mash.new
    else
      logger.trace("Plugin Hardware: namespace already exists")
      next
    end

    require "json"

    # Initialize the hardware hash
    hw_hash = system_profiler("SPHardwareDataType")
    
    # Remove unecessary identifier keys
	hw_hash[0].delete("_name")

    # Normalize the discrepancy between "chip_type" and "cpu_type"
	hw_hash[0]["cpu_type"] = hw_hash[0].delete("chip_type") if hw_hash[0].key?("chip_type")
    
	# Add the hardware hash to the hardware namespace (sorted alphabetically)
	hardware.merge!(hw_hash[0].sort_by { |k, _v| k }.to_h)

	# Initialize the memory hash
    hardware["architecture"] = shell_out("uname -m").stdout.strip
  end
end
