export const useSidebarState = () => {
    const isCollapsed = useState('sidebar-collapsed', () => false)

    const toggleSidebar = () => {
        isCollapsed.value = !isCollapsed.value
    }

    const sidebarWidth = computed(() => isCollapsed.value ? 'w-16 sm:w-20' : 'w-16 sm:w-72')
    const mainMargin = computed(() => isCollapsed.value ? 'ml-16 sm:ml-20' : 'ml-16 sm:ml-72')

    return {
        isCollapsed,
        toggleSidebar,
        sidebarWidth,
        mainMargin
    }
}
