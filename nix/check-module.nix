{
  self,
  pkgs,
  lib ? pkgs.lib,
}:

pkgs.testers.nixosTest {
  name = "donetick-module-healthcheck";
  nodes.machine = { ... }: {
    imports = [ self.nixosModules.donetick ];
    system.stateVersion = "26.05";
    services.donetick = {
      enable = true;
      secrets.jwtSecretFile = pkgs.writeText "jwt-secret" "this-is-definitely-32-characters";
      server.port = 2021;
    };
  };

  testScript = ''
    machine.wait_for_unit("donetick.service")
    machine.wait_for_open_port(2021)
    machine.succeed("curl -fsS http://127.0.0.1:2021/api/v1/health")
  '';
}
