{
  self,
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.testers.nixosTest {
  name = "donetick-module-smoke";

  nodes.machine = { ... }: {
    imports = [ self.nixosModules.donetick ];

    services.donetick = {
      enable = true;
      secrets.jwtSecretFile = pkgs.writeText "jwt-secret" "this-is-a-very-long-test-secret-that-is-definitely-32-chars";
      server.port = 2021;
    };

    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("donetick.service")
    machine.wait_for_open_port(2021)
    machine.succeed("curl -fsS http://127.0.0.1:2021/api/v1/health")
  '';
}
