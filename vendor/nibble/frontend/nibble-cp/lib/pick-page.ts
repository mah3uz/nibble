export function find<T>(modules: Record<string, T>, suffix: string): T | undefined {
  return Object.entries(modules).find(([path]) => path.endsWith(suffix))?.[1]
}

export function pickCpPage<T>(name: string, site: Record<string, T>, app: Record<string, T>) {
  return find(site, `/site/cp/pages/${name}.vue`) ?? app[`../pages/${name}.vue`]
}
