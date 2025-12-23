import { Controller, Get } from "@nestjs/common";

import { AppService } from "./app.service";

/**
 * Application controller that exposes HTTP endpoints.
 */
@Controller()
export class AppController {
  /**
   * Creates an instance of AppController.
   * @param appService - Service layer used to provide greetings
   */
  constructor(private readonly appService: AppService) {}

  /**
   * Returns a greeting string.
   * @returns Greeting message
   */
  @Get()
  getHello(): string {
    return this.appService.getHello();
  }
}
