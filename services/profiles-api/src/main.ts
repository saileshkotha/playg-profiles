import "reflect-metadata";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const port = parseInt(process.env.PORT || "8080", 10);
  const env = process.env.NODE_ENV || "development";
  const sha = process.env.GIT_SHA || "unknown";

  await app.listen(port);
  console.log(`profiles-api listening on :${port}  env=${env}  sha=${sha}`);
}

bootstrap();
