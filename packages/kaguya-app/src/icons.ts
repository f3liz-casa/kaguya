// Bundle only the Tabler icons used in this app — avoids CDN fetch at runtime.
import { addCollection } from 'iconify-icon'
import data from '@iconify-json/tabler/icons.json'

// List every tabler icon referenced via icon="tabler:*" in the codebase
const used = [
  'arrow-back-up',
  'bell',
  'bookmark',
  'bookmark-filled',
  'check',
  'chevron-down',
  'dots',
  'eye',
  'filter',
  'home',
  'loader-2',
  'lock',
  'mail',
  'moon',
  'pencil-plus',
  'photo-plus',
  'plus',
  'repeat',
  'send',
  'settings',
  'sun',
  'world',
  'x',
]

type IconifyIcon = { body: string; width?: number; height?: number }
type IconifyCollection = typeof data & { icons: Record<string, IconifyIcon> }

const subset: IconifyCollection = {
  ...(data as IconifyCollection),
  icons: Object.fromEntries(
    used
      .filter(name => name in (data as IconifyCollection).icons)
      .map(name => [name, (data as IconifyCollection).icons[name]])
  ),
}

addCollection(subset)
