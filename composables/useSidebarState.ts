export const useSidebarState = () => {
    const isCollapsed = useState('sidebar-collapsed', () => false)

    const toggleSidebar = () => {
        isCollapsed.value = !isCollapsed.value
    }

    const sidebarWidth = computed(() => isCollapsed.value ? 'lg:w-20' : 'lg:w-72')
    const desktopMargin = computed(() => isCollapsed.value ? 'lg:ml-20' : 'lg:ml-72')
    const mainMargin = computed(() => ['mt-14 lg:mt-0', desktopMargin.value])

    return {
        isCollapsed,
        toggleSidebar,
        sidebarWidth,
        desktopMargin,
        mainMargin
    }
}
