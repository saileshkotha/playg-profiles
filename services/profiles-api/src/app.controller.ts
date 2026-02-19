import { Controller, Get } from "@nestjs/common";

@Controller()
export class AppController {
  @Get("healthz")
  healthz() {
    return { status: "ok" };
  }

  @Get()
  root() {
    return {
      service: "profiles-api",
      sha: process.env.GIT_SHA || "unknown",
    };
  }
}
