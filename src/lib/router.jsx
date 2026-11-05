import { Children, createContext, isValidElement, useContext, useEffect, useState } from "react";

const currentPath = () => window.location.hash.slice(1) || "/";
const RouterContext = createContext({ path: currentPath(), go: () => {} });

export function BrowserRouter({ children }) {
  const [path, setPath] = useState(currentPath());
  useEffect(() => {
    const onHash = () => setPath(currentPath());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);
  const go = (to, replace = false) => {
    const target = `#${to}`;
    if (replace) window.history.replaceState({}, "", target);
    else window.location.hash = to;
    setPath(to);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };
  return <RouterContext.Provider value={{ path, go }}>{children}</RouterContext.Provider>;
}

export function useNavigate() { const { go } = useContext(RouterContext); return go; }
export function Link({ to, children, onClick, ...props }) {
  const { go } = useContext(RouterContext);
  return <a href={`#${to}`} {...props} onClick={(event) => { onClick?.(event); if (!event.defaultPrevented && !event.metaKey && !event.ctrlKey) { event.preventDefault(); go(to); } }}>{children}</a>;
}
export function Navigate({ to, replace = false }) { const { go } = useContext(RouterContext); useEffect(() => go(to, replace), [to, replace, go]); return null; }
export function Route() { return null; }
export function Routes({ children }) {
  const { path } = useContext(RouterContext);
  const routes = Children.toArray(children).filter(isValidElement);
  const match = routes.find((route) => route.props.path === path) || routes.find((route) => route.props.path === "*");
  return match?.props.element ?? null;
}
