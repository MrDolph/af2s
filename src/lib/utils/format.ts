export function formatNumber(value: number, decimals = 2): string {
  return Number(value.toFixed(decimals)).toString();
}
export function formatTime(seconds: number): string {
  return `${formatNumber(seconds, 1)}s`;
}
export function degreesToRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}
export function radiansToDegrees(radians: number): number {
  return (radians * 180) / Math.PI;
}
