/**
 * Simple wrapper around the fetch API tailored for FiveM NUI.
 *
 * @param eventName - The endpoint event name
 * @param data - Data to send to the client script
 * @param mockData - Mock data to return if in a browser environment
 */
export const fetchNui = async (eventName: string, data?: any, mockData?: any): Promise<any> => {
  const options = {
    method: 'post',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  };

  if (import.meta.env.MODE === 'development' && (window as any).invokeNative === undefined) {
    if (mockData) return mockData;
    return {};
  }

  const resourceName = (window as any).GetParentResourceName
    ? (window as any).GetParentResourceName()
    : 'mbt_backrooms';

  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, options);
    const text = await resp.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      console.error(`[fetchNui] ${eventName}: non-JSON reply (status ${resp.status})`);
      return {};
    }
  } catch (error) {
    if (error instanceof TypeError && error.message === 'Failed to fetch') {
      return {};
    }
    console.error(`[fetchNui] Error fetching ${eventName}:`, error);
    return {};
  }
};
