{ system ? builtins.currentSystem
, config ? { }
, pkgs ? import ../.. { inherit system config; }
}:

with import ../lib/testing-python.nix { inherit system pkgs; };
with pkgs.lib;
{
  btrfs = makeTest
    {
      name = "non-default-filesystems-btrfs";

      nodes.machine =
        { config, pkgs, lib, ... }:
        let
          disk = config.virtualisation.rootDevice;
        in
        {
          virtualisation.rootDevice = "/dev/vda";
          virtualisation.useDefaultFilesystems = false;

          boot.initrd.availableKernelModules = [ "btrfs" ];
          boot.supportedFilesystems = [ "btrfs" ];

          boot.initrd.postDeviceCommands = ''
            FSTYPE=$(blkid -o value -s TYPE ${disk} || true)
            if test -z "$FSTYPE"; then
              modprobe btrfs
              ${pkgs.btrfs-progs}/bin/mkfs.btrfs ${disk}

              mkdir /nixos
              mount -t btrfs ${disk} /nixos

              ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nixos/root
              ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nixos/home

              umount /nixos
            fi
          '';

          virtualisation.fileSystems = {
            "/" = {
              device = disk;
              fsType = "btrfs";
              options = [ "subvol=/root" ];
            };

            "/home" = {
              device = disk;
              fsType = "btrfs";
              options = [ "subvol=/home" ];
            };
          };
        };

      testScript = ''
        machine.wait_for_unit("multi-user.target")

        with subtest("BTRFS filesystems are mounted correctly"):
          machine.succeed("grep -E '/dev/vda / btrfs rw,relatime,space_cache=v2,subvolid=[0-9]+,subvol=/root 0 0' /proc/mounts")
          machine.succeed("grep -E '/dev/vda /home btrfs rw,relatime,space_cache=v2,subvolid=[0-9]+,subvol=/home 0 0' /proc/mounts")
      '';
    };

  erofs =
    let
      fsImage = "/tmp/non-default-filesystem.img";
    in
    makeTest {
      name = "non-default-filesystems-erofs";

      nodes.machine = _: {
        virtualisation.qemu.drives = [{
          name = "non-default-filesystem";
          file = fsImage;
        }];

        virtualisation.fileSystems."/non-default" = {
          device = "/dev/vdb";
          fsType = "erofs";
          neededForBoot = true;
        };
      };

      testScript = ''
        import subprocess
        import tempfile

        with tempfile.TemporaryDirectory() as tmp_dir:
          with open(f"{tmp_dir}/filesystem", "w") as f:
              f.write("erofs")

          subprocess.run([
            "${pkgs.erofs-utils}/bin/mkfs.erofs",
            "${fsImage}",
            tmp_dir,
          ])

        machine.start()
        machine.wait_for_unit("default.target")

        file_contents = machine.succeed("cat /non-default/filesystem")
        assert "erofs" in file_contents
      '';
    };
}
