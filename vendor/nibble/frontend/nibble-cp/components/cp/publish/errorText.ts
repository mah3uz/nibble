export function errorText(label: string | null, message: string): string {
  if (!label) return message

  const wording = message.match(/^The (.+) field (.+)$/)
  if (wording && wording[1].toLowerCase() === label.toLowerCase()) return `${label} ${wording[2]}`

  return message.toLowerCase().includes(label.toLowerCase()) ? message : `${label} ${message}`
}
