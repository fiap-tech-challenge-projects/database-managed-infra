import { Injectable } from "@nestjs/common";

/**
 * Application service providing domain logic.
 */
@Injectable()
export class AppService {
  /**
   * Returns a static greeting.
   * @returns Greeting message
   */
  getHello(): string {
    return "Hello World!";
  }
}
