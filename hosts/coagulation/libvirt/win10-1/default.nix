{ pkgs, NixVirt, ... }:

let
  disk_image = "/var/lib/libvirt/images/win10-1.qcow2";
  gpu_bus_addr = "0000:60:00.0";
  gpu_audio_bus_addr = "0000:60:00.1";
in
{
  virtualisation.libvirt.connections."qemu:///system".domains = [
    {
      definition = NixVirt.lib.domain.writeXML {
        xmlns = {
          qemu = "http://libvirt.org/schemas/domain/qemu/1.0";
        };
        type = "kvm";
        name = "win10-1";
        uuid = "a6a5767d-c20e-4029-9e86-106516315579";
        memory = {
          count = 12;
          unit = "GiB";
        };
        vcpu = {
          count = 8;
          placement = "static";
        };
        os = {
          type = "hvm";
          arch = "x86_64";
          machine = "q35";
          loader = {
            readonly = true;
            type = "pflash";
            path = "${pkgs.OVMFFull.fd}/FV/OVMF_CODE.fd";
          };
          nvram = {
            template = "${pkgs.OVMFFull.fd}/FV/OVMF_VARS.fd";
            path = "/var/lib/libvirt/qemu/nvram/win10-1_VARS.fd";
          };
        };
        features = {
          acpi = { };
          apic = { };
          hyperv = {
            relaxed = {
              state = true;
            };
            vapic = {
              state = true;
            };
            spinlocks = {
              state = true;
              retries = 8191;
            };
            vendor_id = {
              state = true;
              value = "1234567890ab";
            };
          };
          kvm = {
            hidden = {
              state = true;
            };
          };
          vmport = {
            state = false;
          };
          ioapic = {
            driver = "kvm";
          };
        };
        cpu = {
          mode = "host-passthrough";
          check = "none";
        };
        clock = {
          offset = "localtime";
          timer = [
            {
              name = "rtc";
              tickpolicy = "catchup";
            }
            {
              name = "pit";
              tickpolicy = "delay";
            }
            {
              name = "hpet";
              present = false;
            }
            {
              name = "hypervclock";
              present = true;
            }
          ];
        };
        on_poweroff = "destroy";
        on_reboot = "restart";
        on_crash = "destroy";
        devices = {
          emulator = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";
          disk = [
            {
              type = "file";
              device = "disk";
              driver = {
                name = "qemu";
                type = "qcow2";
                cache = "none";
                io = "native";
              };
              source = {
                file = disk_image;
              };
              target = {
                dev = "vda";
                bus = "virtio";
              };
              boot = {
                order = 1;
              };
            }
            {
              type = "file";
              device = "cdrom";
              driver = {
                name = "qemu";
                type = "raw";
              };
              target = {
                dev = "sdb";
                bus = "sata";
              };
              readonly = true;
              boot = {
                order = 2;
              };
            }
          ];
          interface = [
            {
              type = "bridge";
              mac = {
                address = "BC:24:11:F4:68:6F";
              };
              source = {
                bridge = "br0";
              };
              model = {
                type = "virtio";
              };
            }
          ];
          input = [
            {
              type = "tablet";
              bus = "usb";
            }
            {
              type = "mouse";
              bus = "ps2";
            }
            {
              type = "keyboard";
              bus = "ps2";
            }
          ];
          # Disable Primary Virtual GPU
          video = [
            {
              model = {
                type = "none";
              };
            }
          ];
          hostdev = [
            {
              mode = "subsystem";
              type = "pci";
              managed = true;
              alias = {
                name = "hostdev0";
              }; # Alias for QEMU args
              source = {
                address = {
                  domain = 0;
                  bus = 96;
                  slot = 0;
                  function = 0;
                };
              };
            }
            {
              mode = "subsystem";
              type = "pci";
              managed = true;
              source = {
                address = {
                  domain = 0;
                  bus = 96;
                  slot = 0;
                  function = 1;
                };
              };
            }
          ];
          tpms = [
            {
              model = "tpm-tis";
              backend = {
                type = "emulator";
                version = "2.0";
              };
            }
          ];
          graphics = [
            {
              type = "spice";
              autoport = true;
              listen = {
                type = "address";
              };

            }
          ];
          memballoon = {
            model = "virtio";
          };
        };
        qemu_commandline = {
          arg = [
            { value = "-set"; }
            { value = "device.hostdev0.x-pci-sub-vendor-id=0x10de"; }
            { value = "-set"; }
            { value = "device.hostdev0.x-pci-sub-device-id=0x1264"; }
          ];
        };
      };
    }
  ];
}
