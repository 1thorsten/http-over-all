import { useEffect, useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import rehypeSlug from "rehype-slug";
import rehypeAutolinkHeadings from "rehype-autolink-headings";
import { Box } from "@mui/material";
import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { oneDark } from "react-syntax-highlighter/dist/esm/styles/prism";

export default function ReadmeTab() {
    const [markdown, setMarkdown] = useState("");

    useEffect(() => {
        fetch("/f/README.md").then((res) => res.text()).then(setMarkdown);
    }, []);

    return (
        <Box   sx={{
            typography: "body1",
            px: 2,
            py: 1,
            a: {
                color: "primary.light", // Oder ein expliziter Farbwert wie "#90caf9"
                textDecoration: "underline",
                '&:hover': {
                    color: "primary.main",
                },
            },
            "table": {
                width: "100%",
                borderCollapse: "collapse",
                marginTop: 2,
            },
            "th, td": {
                border: "1px solid",
                borderColor: "divider",
                padding: "8px",
                textAlign: "left",
            },
            "th": {
                backgroundColor: "action.hover",
            },
        }}>
            <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                rehypePlugins={[rehypeSlug, rehypeAutolinkHeadings]}
                components={{
                    code: (props) => {
                        const { inline, className, children, ...rest } = props as any;
                        const match = /language-(\w+)/.exec(className || "");

                        return !inline && match ? (
                            <SyntaxHighlighter
                                style={oneDark}
                                language={match[1]}
                                PreTag="div"
                                {...rest}
                            >
                                {String(children).replace(/\n$/, "")}
                            </SyntaxHighlighter>
                        ) : (
                            <code {...rest}>{children}</code>
                        );
                    },
                }}
            >
                {markdown}
            </ReactMarkdown>
        </Box>
    );
}
